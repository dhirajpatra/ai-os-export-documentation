"""
services/agents/template_matcher.py
=====================================
Layer 2 of the three-layer extraction pipeline.

Storage architecture
--------------------
  DB (Neon/Postgres)   — source of truth, survives Redis eviction
  Redis (Upstash)      — cache layer, ~1ms reads

Read path  (match):
  1. Redis hit  → return immediately (fastest)
  2. Redis miss → query DB → repopulate Redis → return
  3. DB miss    → return None → LLM fires

Write path (learn):
  1. Upsert to DB  (INSERT ... ON CONFLICT DO UPDATE)
  2. Write to Redis
  → Both always in sync after every learn() call

Reinforcement learning
----------------------
Every successful extraction updates:
  use_count           — total times template consulted
  template_hit_count  — times template was sufficient (no LLM)
  llm_fallback_count  — times LLM was still needed
  avg_confidence      — running average of extraction confidence
  last_extraction_confidence — most recent extraction score

After ~5 shipments from a buyer, avg_confidence stabilises and the
template reliably routes that buyer to Layer 1/2, skipping LLM entirely.

Dashboard endpoint
------------------
GET /api/v1/templates  returns all learned buyers for the org —
powers the "Learned Buyers" panel in the React frontend.
"""

from __future__ import annotations

import hashlib
import json
import re
import uuid
from typing import Optional

from core.redis_client import get_redis
from services.agents.rule_based_extractor import RuleBasedExtractor


# ── Redis TTL ────────────────────────────────────────────────────────────────
_REDIS_TTL = 60 * 60 * 24 * 7   # 7 days in Redis; DB is permanent


# ── Key helpers ───────────────────────────────────────────────────────────────

def _redis_key(org_id: str, buyer_key: str) -> str:
    return f"po_template:{org_id}:{buyer_key}"

def _fp_key(org_id: str, fingerprint: str) -> str:
    return f"po_fp:{org_id}:{fingerprint}"

def buyer_key_from_name(buyer_name: str) -> str:
    """Normalise buyer name → stable slug. Public so routes.py can use it."""
    s = re.sub(r"[^a-z0-9]", "_", buyer_name.lower().strip())
    return re.sub(r"_+", "_", s).strip("_")[:40]

def _text_fingerprint(text: str) -> str:
    labels = re.findall(
        r"\b(qty|quantity|weight|payment|incoterm|cif|fob|lc|currency|"
        r"buyer|consignee|product|item|description|unit|price|total|"
        r"shipment|delivery|port|destination)\b",
        text.lower(),
    )
    return hashlib.md5("|".join(sorted(set(labels))).encode()).hexdigest()[:12]


# ─────────────────────────────────────────────────────────────────────────────
# TEMPLATE MATCHER
# ─────────────────────────────────────────────────────────────────────────────

class TemplateMatcher:

    @classmethod
    async def match(
        cls,
        raw_text:   str,
        org_id:     str,
        buyer_name: Optional[str] = None,
    ) -> Optional[dict]:
        """
        Try to find a matching template for this PO.
        Returns extracted dict or None.
        """
        candidates = []
        if buyer_name and len(buyer_name) > 2:
            candidates.append(buyer_key_from_name(buyer_name))

        # Fingerprint-based lookup (format match without knowing buyer name)
        fp = _text_fingerprint(raw_text)
        try:
            fp_stored = await get_redis().get(_fp_key(org_id, fp))
            if fp_stored and fp_stored not in candidates:
                candidates.append(fp_stored)
        except Exception:
            pass

        for bk in candidates:
            template = await cls._load_template(org_id, bk)
            if not template:
                continue

            result = cls._apply_template(raw_text, template)
            if result and result["confidence"] >= 55.0:
                # Record template was consulted — async fire-and-forget
                await cls._increment_counter(org_id, bk, hit=True)
                result["_source"]         = "template_match"
                result["_template_buyer"] = template.get("buyer_name")
                return result

            # Template found but confidence too low — still count the consult
            await cls._increment_counter(org_id, bk, hit=False)

        return None

    @classmethod
    async def learn(
        cls,
        raw_text:   str,
        extracted:  dict,
        org_id:     str,
        buyer_name: Optional[str] = None,
        llm_used:   bool = True,
    ) -> None:
        """
        Learn or update a buyer template from a successful extraction.
        Call after every extraction (LLM or rule-based) with confidence
        above CONFIDENCE_THRESHOLD_HUMAN.
        """
        name = buyer_name or extracted.get("buyer_name") or ""
        if not name or len(name) < 3:
            return

        bk      = buyer_key_from_name(name)
        anchors = cls._build_anchors(raw_text, extracted)
        conf    = float(extracted.get("confidence", 80.0))

        template = {
            "buyer_key":        bk,
            "buyer_name":       name,
            "buyer_country":    extracted.get("buyer_country"),
            "currency":         extracted.get("currency", "USD"),
            "payment_terms":    extracted.get("payment_terms"),
            "incoterms":        extracted.get("incoterms"),
            "destination_port": extracted.get("destination_port"),
            "anchors":          anchors,
            "sample_confidence": conf,
        }

        # Save to DB first (durable), then cache in Redis
        await cls._upsert_db(org_id, template, conf, llm_used)
        await cls._write_redis(org_id, bk, template)

        # Store fingerprint → buyer_key mapping
        fp = _text_fingerprint(raw_text)
        try:
            await get_redis().setex(_fp_key(org_id, fp), _REDIS_TTL, bk)
        except Exception:
            pass

        print(f"[TemplateMatcher] learned/updated template for '{name}' (llm_used={llm_used})")

    # ── Template application ──────────────────────────────────────────────────

    @classmethod
    def _apply_template(cls, raw_text: str, template: dict) -> Optional[dict]:
        """
        Apply stored template to new raw_text.
        Uses rule-based extractor for variable fields, fills
        stable fields from template.
        """
        result = RuleBasedExtractor.extract(raw_text)

        # Fill gaps from template stable fields
        stable = [
            "buyer_name", "buyer_country", "currency",
            "payment_terms", "incoterms", "destination_port", "destination_country",
        ]
        filled = 0
        for field in stable:
            if not result.get(field) and template.get(field):
                result[field] = template[field]
                filled += 1

        # Boost confidence for each template-filled field
        result["confidence"] = min(95.0, result["confidence"] + (filled * 5.0))

        # Remove clarifications for fields now filled
        result["requires_clarification"] = [
            c for c in result.get("requires_clarification", [])
            if not result.get(c["field"])
        ]

        return result

    # ── DB operations ─────────────────────────────────────────────────────────

    @classmethod
    async def _upsert_db(
        cls,
        org_id:   str,
        template: dict,
        conf:     float,
        llm_used: bool,
    ) -> None:
        """
        INSERT or UPDATE po_templates row.
        ON CONFLICT: update counters + fill any null stable fields.
        """
        try:
            from core.db import get_pool
            pool = get_pool()
            async with pool.acquire() as db:
                await db.execute(
                    """
                    INSERT INTO po_templates (
                        org_id, buyer_key, buyer_name, buyer_country,
                        currency, payment_terms, incoterms, destination_port,
                        field_anchors, use_count, avg_confidence,
                        last_extraction_confidence,
                        template_hit_count, llm_fallback_count,
                        last_used_at
                    ) VALUES (
                        $1, $2, $3, $4,
                        $5, $6, $7, $8,
                        $9::jsonb, 1, $10,
                        $10,
                        $11, $12,
                        NOW()
                    )
                    ON CONFLICT (org_id, buyer_key) DO UPDATE SET
                        buyer_name       = COALESCE($3,  po_templates.buyer_name),
                        buyer_country    = COALESCE($4,  po_templates.buyer_country),
                        currency         = COALESCE($5,  po_templates.currency),
                        payment_terms    = COALESCE($6,  po_templates.payment_terms),
                        incoterms        = COALESCE($7,  po_templates.incoterms),
                        destination_port = COALESCE($8,  po_templates.destination_port),
                        field_anchors    = $9::jsonb,
                        use_count        = po_templates.use_count + 1,
                        avg_confidence   = ROUND(
                                            ((po_templates.avg_confidence * po_templates.use_count) + $10)
                                            / (po_templates.use_count + 1)::float,
                                           2),
                        last_extraction_confidence = $10,
                        template_hit_count  = po_templates.template_hit_count  + $11,
                        llm_fallback_count  = po_templates.llm_fallback_count  + $12,
                        last_used_at        = NOW()
                    """,
                    uuid.UUID(org_id),
                    template["buyer_key"],
                    template.get("buyer_name"),
                    template.get("buyer_country"),
                    template.get("currency"),
                    template.get("payment_terms"),
                    template.get("incoterms"),
                    template.get("destination_port"),
                    json.dumps(template.get("anchors", [])),
                    conf,
                    0 if llm_used else 1,   # template_hit_count delta
                    1 if llm_used else 0,   # llm_fallback_count delta
                )
        except Exception as exc:
            print(f"[TemplateMatcher._upsert_db] DB error (non-fatal): {exc}")

    @classmethod
    async def _load_template(cls, org_id: str, buyer_key: str) -> Optional[dict]:
        """
        Load template: Redis first, DB fallback.
        Repopulates Redis from DB on cache miss.
        """
        # 1. Redis
        try:
            raw = await get_redis().get(_redis_key(org_id, buyer_key))
            if raw:
                return json.loads(raw)
        except Exception:
            pass

        # 2. DB fallback
        try:
            from core.db import get_pool
            pool = get_pool()
            async with pool.acquire() as db:
                row = await db.fetchrow(
                    """
                    SELECT buyer_key, buyer_name, buyer_country,
                           currency, payment_terms, incoterms,
                           destination_port, field_anchors,
                           use_count, avg_confidence
                    FROM   po_templates
                    WHERE  org_id = $1 AND buyer_key = $2
                    """,
                    uuid.UUID(org_id), buyer_key,
                )
                if row:
                    template = {
                        "buyer_key":        row["buyer_key"],
                        "buyer_name":       row["buyer_name"],
                        "buyer_country":    row["buyer_country"],
                        "currency":         row["currency"],
                        "payment_terms":    row["payment_terms"],
                        "incoterms":        row["incoterms"],
                        "destination_port": row["destination_port"],
                        "anchors":          row["field_anchors"] or [],
                        "sample_confidence": float(row["avg_confidence"] or 80.0),
                        "uses":             row["use_count"],
                    }
                    # Repopulate Redis
                    await cls._write_redis(org_id, buyer_key, template)
                    return template
        except Exception as exc:
            print(f"[TemplateMatcher._load_template] DB error (non-fatal): {exc}")

        return None

    @classmethod
    async def _write_redis(cls, org_id: str, buyer_key: str, template: dict) -> None:
        try:
            await get_redis().setex(
                _redis_key(org_id, buyer_key),
                _REDIS_TTL,
                json.dumps(template),
            )
        except Exception:
            pass

    @classmethod
    async def _increment_counter(cls, org_id: str, buyer_key: str, hit: bool) -> None:
        """Lightweight counter update — does not touch Redis cache."""
        try:
            from core.db import get_pool
            pool = get_pool()
            async with pool.acquire() as db:
                if hit:
                    await db.execute(
                        """UPDATE po_templates
                           SET template_hit_count = template_hit_count + 1,
                               last_used_at = NOW()
                           WHERE org_id = $1 AND buyer_key = $2""",
                        uuid.UUID(org_id), buyer_key,
                    )
                else:
                    await db.execute(
                        """UPDATE po_templates
                           SET use_count = use_count + 1,
                               last_used_at = NOW()
                           WHERE org_id = $1 AND buyer_key = $2""",
                        uuid.UUID(org_id), buyer_key,
                    )
        except Exception:
            pass

    # ── Anchor builder ────────────────────────────────────────────────────────

    @classmethod
    def _build_anchors(cls, raw_text: str, extracted: dict) -> list[dict]:
        anchors = []
        field_signals = {
            "payment_terms":    ["payment", "lc", "l/c", "tt", "t/t", "terms"],
            "incoterms":        ["cif", "fob", "cfr", "exw", "ddp", "incoterms"],
            "destination_port": ["jebel ali", "dubai", "jeddah", "doha", "muscat",
                                 "port of discharge", "destination"],
            "currency":         ["usd", "aed", "eur", "currency"],
        }
        tl = raw_text.lower()
        for field, signals in field_signals.items():
            found = [s for s in signals if s in tl]
            if found and extracted.get(field):
                anchors.append({
                    "field":   field,
                    "signals": found[:3],
                    "value":   extracted[field],
                })
        return anchors


# ─────────────────────────────────────────────────────────────────────────────
# LIST TEMPLATES — used by dashboard API endpoint
# ─────────────────────────────────────────────────────────────────────────────

async def list_templates(org_id: str) -> list[dict]:
    """
    Return all learned buyer templates for an org, ordered by use_count.
    Powers GET /api/v1/templates dashboard endpoint.
    """
    try:
        from core.db import get_pool
        pool = get_pool()
        async with pool.acquire() as db:
            rows = await db.fetch(
                """
                SELECT
                    buyer_name, buyer_country, currency,
                    payment_terms, incoterms, destination_port,
                    use_count, avg_confidence,
                    template_hit_count, llm_fallback_count,
                    last_extraction_confidence,
                    last_used_at, created_at,
                    ROUND(
                        CASE WHEN use_count > 0
                        THEN (template_hit_count::float / use_count) * 100
                        ELSE 0 END
                    , 1) AS hit_rate_pct
                FROM   po_templates
                WHERE  org_id = $1
                ORDER  BY use_count DESC
                """,
                uuid.UUID(org_id),
            )
            return [dict(r) for r in rows]
    except Exception as exc:
        print(f"[list_templates] DB error: {exc}")
        return []

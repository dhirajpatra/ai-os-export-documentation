"""
services/agents/template_matcher.py
=====================================
Layer 2 of the three-layer extraction pipeline.

Once you have seen a buyer's PO format once, you store a template.
Subsequent POs from the same buyer are parsed structurally — field positions,
column headers, label patterns — instead of sending to the LLM.

Architecture
------------
Templates are stored in Redis (key: template:{org_id}:{buyer_key})
and optionally persisted to the agent_memory table.

On first encounter (new buyer / new format):
  - LLM extracts the fields (existing flow)
  - TemplateMatcher.learn() is called with the raw text + extracted result
  - A template fingerprint is computed and saved

On subsequent POs:
  - TemplateMatcher.match() tries to match the raw text
  - If confidence ≥ threshold → returns structured result, no LLM call

Template fingerprint stores
  - buyer_key     (normalised name slug)
  - label_anchors (regex anchors for known field labels in this buyer's format)
  - field_map     (which anchor maps to which schema field)
  - sample_confidence  (avg confidence from past extractions for this buyer)

Usage in po_extraction.py
--------------------------
    tm_result = await TemplateMatcher.match(raw_text, org_id)
    if tm_result and tm_result["confidence"] >= cfg.CONFIDENCE_THRESHOLD_AUTO:
        return tm_result   # skip LLM
    ...
    # after successful LLM extraction:
    await TemplateMatcher.learn(raw_text, extracted, org_id, buyer_name)
"""

from __future__ import annotations

import hashlib
import json
import re
import uuid
from typing import Optional

from core.redis_client import get_redis
from services.agents.rule_based_extractor import RuleBasedExtractor


# ── Redis key helpers ─────────────────────────────────────────────────────────

def _template_key(org_id: str, buyer_key: str) -> str:
    return f"po_template:{org_id}:{buyer_key}"

def _buyer_key(buyer_name: str) -> str:
    """Normalise buyer name → slug for use as Redis key segment."""
    s = re.sub(r"[^a-z0-9]", "_", buyer_name.lower().strip())
    return re.sub(r"_+", "_", s).strip("_")[:40]

def _text_fingerprint(text: str) -> str:
    """Structural fingerprint — which label words appear, ignoring values."""
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
    """
    Buyer-specific PO template learning and matching.

    All operations are async (Redis I/O).
    Falls back gracefully if Redis is unavailable.
    """

    TTL_SECONDS = 60 * 60 * 24 * 90   # 90 days

    @classmethod
    async def match(
        cls,
        raw_text: str,
        org_id: str,
        buyer_name: Optional[str] = None,
    ) -> Optional[dict]:
        """
        Try to match raw_text against known buyer templates.

        Returns extracted dict (same schema as _default_schema) if matched,
        or None if no template found / confidence too low.
        """
        try:
            r = get_redis()

            # If buyer name known, try their template directly
            candidates = []
            if buyer_name:
                candidates.append(_buyer_key(buyer_name))

            # Also try fingerprint-based lookup (format match without knowing buyer)
            fp = _text_fingerprint(raw_text)
            fp_key = f"po_fp:{org_id}:{fp}"
            stored_buyer_key = await r.get(fp_key)
            if stored_buyer_key and stored_buyer_key not in candidates:
                candidates.append(stored_buyer_key)

            for bk in candidates:
                raw = await r.get(_template_key(org_id, bk))
                if not raw:
                    continue

                template = json.loads(raw)
                result   = cls._apply_template(raw_text, template)
                if result and result["confidence"] >= 55.0:
                    result["_source"]        = "template_match"
                    result["_template_buyer"] = template.get("buyer_name")
                    return result

        except Exception as exc:
            print(f"[TemplateMatcher.match] Redis error (non-fatal): {exc}")

        return None

    @classmethod
    async def learn(
        cls,
        raw_text: str,
        extracted: dict,
        org_id: str,
        buyer_name: Optional[str] = None,
    ) -> None:
        """
        Learn a template from a successfully LLM-extracted PO.
        Call this after every successful LLM extraction.

        Stores:
          - Buyer template in Redis
          - Fingerprint → buyer_key mapping in Redis
        """
        name = buyer_name or extracted.get("buyer_name") or ""
        if not name or len(name) < 3:
            return   # can't learn without a buyer identity

        bk = _buyer_key(name)

        try:
            r = get_redis()

            # Build label anchor map — which regex patterns reliably appear
            # in this buyer's PO format and map to which fields
            anchors = cls._build_anchors(raw_text, extracted)

            template = {
                "buyer_name":       name,
                "buyer_key":        bk,
                "buyer_country":    extracted.get("buyer_country"),
                "currency":         extracted.get("currency", "USD"),
                "payment_terms":    extracted.get("payment_terms"),
                "incoterms":        extracted.get("incoterms"),
                "destination_port": extracted.get("destination_port"),
                "anchors":          anchors,
                "sample_confidence": extracted.get("confidence", 80.0),
                "uses":             1,
            }

            key = _template_key(org_id, bk)

            # Merge with existing if present (increment use count)
            existing_raw = await r.get(key)
            if existing_raw:
                existing = json.loads(existing_raw)
                template["uses"] = existing.get("uses", 1) + 1
                # Update stable fields only — don't override with None
                for f in ["buyer_country", "currency", "payment_terms",
                           "incoterms", "destination_port"]:
                    if not template[f] and existing.get(f):
                        template[f] = existing[f]

            await r.setex(key, cls.TTL_SECONDS, json.dumps(template))

            # Store fingerprint → buyer_key mapping
            fp     = _text_fingerprint(raw_text)
            fp_key = f"po_fp:{org_id}:{fp}"
            await r.setex(fp_key, cls.TTL_SECONDS, bk)

            print(f"[TemplateMatcher] learned template for '{name}' (uses={template['uses']})")

        except Exception as exc:
            print(f"[TemplateMatcher.learn] Redis error (non-fatal): {exc}")

    # ── Internal helpers ──────────────────────────────────────────────────────

    @classmethod
    def _apply_template(cls, raw_text: str, template: dict) -> Optional[dict]:
        """
        Apply a stored template to new raw text.
        Uses rule-based extractor + fills stable fields from template.
        """
        # Start with rule-based extraction
        result = RuleBasedExtractor.extract(raw_text)

        # Fill missing fields from template's stable values
        stable_fields = [
            "buyer_name", "buyer_country", "currency",
            "payment_terms", "incoterms", "destination_port", "destination_country",
        ]
        for field in stable_fields:
            if not result.get(field) and template.get(field):
                result[field] = template[field]

        # Re-score confidence — template fills add points
        filled_from_template = sum(
            1 for f in stable_fields
            if not RuleBasedExtractor.extract(raw_text).get(f) and template.get(f)
        )
        result["confidence"] = min(
            95.0,
            result["confidence"] + (filled_from_template * 5.0)
        )

        # Re-run clarification check with new fields
        result["requires_clarification"] = [
            c for c in result["requires_clarification"]
            if not result.get(c["field"])
        ]

        return result

    @classmethod
    def _build_anchors(cls, raw_text: str, extracted: dict) -> list[dict]:
        """
        Identify which label words in this text reliably signal which fields.
        Stored so future matching can verify field presence.
        """
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

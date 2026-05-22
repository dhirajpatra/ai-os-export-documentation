"""
TradeOS — Agent Memory Layer
==============================
Agents learn: customer preferences, shipment patterns, HS codes,
vendor behavior, invoice styles, country rules.
Backed by PostgreSQL + pgvector for semantic recall.
"""

from __future__ import annotations

import hashlib
import json
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Any
import os
from dotenv import load_dotenv
load_dotenv()


# ─────────────────────────────────────────────
# MEMORY TYPES
# ─────────────────────────────────────────────

MEMORY_TYPES = {
    "customer_preference":  "What this buyer prefers: currency, port, packing, doc format",
    "shipment_pattern":     "Recurring routes, carriers, containers, seasonal peaks",
    "hs_code_learned":      "HS codes validated for this org's product catalog",
    "vendor_behavior":      "Supplier reliability, lead times, quality patterns",
    "invoice_style":        "Buyer-preferred invoice layout, fields, language",
    "country_rule":         "Trade rules learned from past shipments to this country",
    "workflow_shortcut":    "Steps this org always skips or always does in a custom order",
    "risk_pattern":         "Risk signals: late payments, compliance issues, disputes",
    "seasonal_pattern":     "Order spikes, slow periods, pre-Ramadan, Diwali, Christmas",
}


# ─────────────────────────────────────────────
# MEMORY RECORD
# ─────────────────────────────────────────────

@dataclass
class MemoryRecord:
    id:                 str   = field(default_factory=lambda: str(uuid.uuid4()))
    org_id:             str   = ""
    agent_name:         str   = ""
    memory_type:        str   = ""
    scope_type:         str   = "org"         # org | contact | product | route
    scope_id:           str | None = None     # contact_id / product_id / "IN-AE"
    key:                str   = ""
    value:              Any   = None
    confidence:         float = 50.0
    source:             str   = "observation" # observation | feedback | inference
    observation_count:  int   = 1
    last_observed_at:   str   = field(default_factory=lambda: datetime.utcnow().isoformat())
    expires_at:         str | None = None
    embedding:          list[float] | None = None  # 1536-dim for OpenAI ada-002

    @property
    def is_expired(self) -> bool:
        if not self.expires_at:
            return False
        return datetime.utcnow().isoformat() > self.expires_at

    @property
    def value_hash(self) -> str:
        return hashlib.md5(json.dumps(self.value, sort_keys=True).encode()).hexdigest()[:8]

    def reinforce(self, new_confidence: float | None = None):
        """Call when same pattern is observed again."""
        self.observation_count += 1
        self.last_observed_at = datetime.utcnow().isoformat()
        if new_confidence:
            # Weighted average: existing confidence + new observation
            self.confidence = (self.confidence * 0.7) + (new_confidence * 0.3)
        else:
            # Observing again boosts confidence, capped at 98
            self.confidence = min(98.0, self.confidence + (100 - self.confidence) * 0.1)


# ─────────────────────────────────────────────
# MEMORY STORE
# ─────────────────────────────────────────────

class AgentMemoryStore:
    """
    In-process cache backed by PostgreSQL + pgvector.
    Production: async SQLAlchemy + asyncpg.
    Embedding: OpenAI ada-002 or sentence-transformers local.
    """

    def __init__(self, org_id: str, db=None, embedder=None):
        self.org_id   = org_id
        self.db       = db
        self.embedder = embedder
        self._cache:  dict[str, MemoryRecord] = {}   # hot cache: key → record

    # ── WRITE ─────────────────────────────────────────────

    async def remember(
        self,
        agent_name:    str,
        memory_type:   str,
        key:           str,
        value:         Any,
        scope_type:    str   = "org",
        scope_id:      str | None = None,
        confidence:    float = 70.0,
        source:        str   = "observation",
        ttl_days:      int | None = None,
    ) -> MemoryRecord:
        """
        Upsert a memory. If same key exists → reinforce.
        Generates embedding for semantic search.
        """
        cache_key = self._cache_key(agent_name, memory_type, scope_type, scope_id, key)
        existing  = self._cache.get(cache_key)

        if existing and not existing.is_expired:
            # Reinforce existing observation
            existing.reinforce(confidence)
            existing.value = value  # update to latest
            record = existing
        else:
            record = MemoryRecord(
                org_id           = self.org_id,
                agent_name       = agent_name,
                memory_type      = memory_type,
                scope_type       = scope_type,
                scope_id         = scope_id,
                key              = key,
                value            = value,
                confidence       = confidence,
                source           = source,
                expires_at       = (
                    (datetime.utcnow() + timedelta(days=ttl_days)).isoformat()
                    if ttl_days else None
                ),
            )

        # Generate embedding for semantic recall
        if self.embedder:
            text_repr = f"{memory_type} {key}: {json.dumps(value)}"
            record.embedding = await self.embedder.embed(text_repr)

        self._cache[cache_key] = record

        # In production: upsert to agent_memory table
        # await self.db.execute(UPSERT_MEMORY_SQL, record)

        return record

    # ── READ: Exact ───────────────────────────────────────

    async def recall(
        self,
        agent_name:   str,
        memory_type:  str,
        key:          str,
        scope_type:   str = "org",
        scope_id:     str | None = None,
        min_confidence: float = 0.0,
    ) -> MemoryRecord | None:
        cache_key = self._cache_key(agent_name, memory_type, scope_type, scope_id, key)
        record    = self._cache.get(cache_key)
        if record and not record.is_expired and record.confidence >= min_confidence:
            return record
        # In production: SELECT FROM agent_memory WHERE ...
        return None

    # ── READ: Semantic ────────────────────────────────────

    async def search(
        self,
        query:        str,
        agent_name:   str | None = None,
        memory_type:  str | None = None,
        scope_type:   str | None = None,
        scope_id:     str | None = None,
        top_k:        int = 5,
        min_confidence: float = 40.0,
    ) -> list[MemoryRecord]:
        """
        Semantic search via pgvector cosine similarity.
        Filters by agent/type/scope before vector search.
        """
        if self.embedder:
            query_embedding = await self.embedder.embed(query)
            # In production:
            # SELECT * FROM agent_memory
            # WHERE org_id = $1
            #   AND ($2 IS NULL OR agent_name = $2)
            #   AND ($3 IS NULL OR memory_type = $3)
            #   AND confidence >= $4
            #   AND (expires_at IS NULL OR expires_at > NOW())
            # ORDER BY embedding <=> $5::vector
            # LIMIT $6
        else:
            # Fallback: keyword match over cache
            results = []
            for record in self._cache.values():
                if record.org_id != self.org_id:
                    continue
                if record.is_expired:
                    continue
                if record.confidence < min_confidence:
                    continue
                if agent_name and record.agent_name != agent_name:
                    continue
                if memory_type and record.memory_type != memory_type:
                    continue
                if scope_type and record.scope_type != scope_type:
                    continue
                if scope_id and record.scope_id != scope_id:
                    continue
                text = f"{record.key} {json.dumps(record.value)}".lower()
                if any(word in text for word in query.lower().split()):
                    results.append(record)
            return sorted(results, key=lambda r: r.confidence, reverse=True)[:top_k]

        return []

    # ── FORGET ────────────────────────────────────────────

    async def forget(self, agent_name: str, memory_type: str, key: str,
                     scope_type: str = "org", scope_id: str | None = None):
        cache_key = self._cache_key(agent_name, memory_type, scope_type, scope_id, key)
        self._cache.pop(cache_key, None)
        # In production: DELETE FROM agent_memory WHERE ...

    async def expire_scope(self, scope_type: str, scope_id: str):
        """When a contact is deleted, expire all their memories."""
        to_delete = [
            k for k, r in self._cache.items()
            if r.scope_type == scope_type and r.scope_id == scope_id
        ]
        for k in to_delete:
            del self._cache[k]

    @staticmethod
    def _cache_key(agent_name, memory_type, scope_type, scope_id, key) -> str:
        return f"{agent_name}::{memory_type}::{scope_type}::{scope_id}::{key}"


# ─────────────────────────────────────────────
# MEMORY PROFILES (pre-built per entity type)
# ─────────────────────────────────────────────

class BuyerMemoryProfile:
    """
    Everything the system learns about a specific buyer over time.
    Populated by observations across all agents.
    """

    def __init__(self, store: AgentMemoryStore, contact_id: str):
        self.store      = store
        self.contact_id = contact_id
        self._scope     = {"scope_type": "contact", "scope_id": contact_id}

    async def learn_currency_preference(self, currency: str, confidence: float = 75.0):
        await self.store.remember(
            agent_name  = "po_extraction_agent",
            memory_type = "customer_preference",
            key         = "preferred_currency",
            value       = {"currency": currency},
            confidence  = confidence,
            **self._scope,
        )

    async def learn_port_preference(self, port: str, country: str):
        await self.store.remember(
            agent_name  = "logistics_agent",
            memory_type = "customer_preference",
            key         = "preferred_destination_port",
            value       = {"port": port, "country": country},
            **self._scope,
        )

    async def learn_payment_pattern(self, payment_terms: str, on_time_rate: float):
        await self.store.remember(
            agent_name  = "finance_agent",
            memory_type = "risk_pattern",
            key         = "payment_behavior",
            value       = {"usual_terms": payment_terms, "on_time_rate": on_time_rate},
            confidence  = 80.0,
            **self._scope,
        )

    async def learn_invoice_style(self, style_sample: dict):
        """Learn what fields this buyer cares about on invoices."""
        await self.store.remember(
            agent_name  = "doc_generation_agent",
            memory_type = "invoice_style",
            key         = "preferred_invoice_fields",
            value       = style_sample,
            confidence  = 85.0,
            **self._scope,
        )

    async def learn_sku_pattern(self, sku: str, hs_code: str, validated: bool):
        await self.store.remember(
            agent_name  = "hs_validation_agent",
            memory_type = "hs_code_learned",
            key         = f"sku_{sku}",
            value       = {"hs_code": hs_code, "validated": validated},
            confidence  = 90.0 if validated else 60.0,
            **self._scope,
        )

    async def get_context_for_po(self) -> dict:
        """Assemble full buyer context for PO extraction prompt."""
        memories = await self.store.search(
            query       = "buyer preferences currency port payment invoice",
            scope_type  = "contact",
            scope_id    = self.contact_id,
            top_k       = 10,
        )
        return {
            "buyer_memories": [
                {
                    "type":       m.memory_type,
                    "key":        m.key,
                    "value":      m.value,
                    "confidence": m.confidence,
                    "seen":       m.observation_count,
                }
                for m in memories
            ]
        }


class RouteMemoryProfile:
    """Learned knowledge about a specific trade route (e.g. IN → AE)."""

    def __init__(self, store: AgentMemoryStore, from_country: str, to_country: str):
        self.store   = store
        self.route   = f"{from_country}-{to_country}"
        self._scope  = {"scope_type": "route", "scope_id": self.route}

    async def learn_transit_time(self, carrier: str, days: int, service: str):
        await self.store.remember(
            agent_name  = "logistics_agent",
            memory_type = "shipment_pattern",
            key         = f"transit_{carrier}_{service}",
            value       = {"days": days, "carrier": carrier, "service": service},
            confidence  = 85.0,
            **self._scope,
        )

    async def learn_compliance_rule(self, hs_prefix: str, rule: dict):
        await self.store.remember(
            agent_name  = "compliance_agent",
            memory_type = "country_rule",
            key         = f"hs_{hs_prefix}_rule",
            value       = rule,
            confidence  = 90.0,
            ttl_days    = 180,  # Compliance rules can change — expire after 6 months
            **self._scope,
        )

    async def get_route_context(self) -> dict:
        memories = await self.store.search(
            query      = "transit time customs duty compliance",
            scope_type = "route",
            scope_id   = self.route,
            top_k      = 8,
        )
        return {"route_memories": [{"key": m.key, "value": m.value} for m in memories]}


# ─────────────────────────────────────────────
# MEMORY OBSERVER
# Plugged into workflow events — learns automatically
# ─────────────────────────────────────────────

class MemoryObserver:
    """
    Listens to workflow events and auto-populates memory.
    Zero manual annotation required.
    """

    def __init__(self, store: AgentMemoryStore):
        self.store = store

    async def on_event(self, event: dict):
        event_type = event.get("event")
        data       = event.get("data", {})
        handlers   = {
            "workflow.completed":     self._on_workflow_completed,
            "step.completed":         self._on_step_completed,
            "approval.approved":      self._on_approval_approved,
            "shipment.delivered":     self._on_shipment_delivered,
            "payment.received":       self._on_payment_received,
            "compliance.flag_raised": self._on_compliance_flag,
        }
        handler = handlers.get(event_type)
        if handler:
            await handler(data)

    async def _on_workflow_completed(self, data: dict):
        ctx = data.get("ctx", {})

        # Learn buyer's currency
        buyer_id = ctx.get("extracted_po", {}).get("buyer_contact_id")
        currency = ctx.get("extracted_po", {}).get("currency")
        if buyer_id and currency:
            buyer_profile = BuyerMemoryProfile(self.store, buyer_id)
            await buyer_profile.learn_currency_preference(currency)

        # Learn HS codes
        for v in ctx.get("hs_validations", {}).get("validations", []):
            if v.get("is_valid") and v.get("confidence", 0) > 85:
                await self.store.remember(
                    agent_name  = "hs_validation_agent",
                    memory_type = "hs_code_learned",
                    key         = v["validated_hs_code"],
                    value       = {"description": v["original_description"]},
                    confidence  = v["confidence"],
                )

    async def _on_step_completed(self, data: dict):
        pass  # step-level learning hooks

    async def _on_approval_approved(self, data: dict):
        """Human approved with overrides → high-confidence learning event."""
        overrides = data.get("field_overrides", {})
        if overrides:
            await self.store.remember(
                agent_name  = "doc_generation_agent",
                memory_type = "invoice_style",
                key         = "human_override_pattern",
                value       = overrides,
                confidence  = os.getenv("CONFIDENCE_THRESHOLD_AUTO",90),
                source      = "feedback",
            )

    async def _on_shipment_delivered(self, data: dict):
        route   = data.get("route")
        carrier = data.get("carrier")
        days    = data.get("transit_days")
        if route and carrier and days:
            from_c, to_c = route.split("-") if "-" in route else ("IN", "AE")
            profile = RouteMemoryProfile(self.store, from_c, to_c)
            await profile.learn_transit_time(carrier, int(days), data.get("service", "standard"))

    async def _on_payment_received(self, data: dict):
        buyer_id    = data.get("buyer_id")
        days_to_pay = data.get("days_to_pay", 0)
        terms       = data.get("payment_terms", "")
        if buyer_id:
            on_time = days_to_pay <= (30 if "30" in terms else 60)
            profile = BuyerMemoryProfile(self.store, buyer_id)
            await profile.learn_payment_pattern(terms, on_time_rate=1.0 if on_time else 0.0)

    async def _on_compliance_flag(self, data: dict):
        route     = data.get("route", "IN-AE")
        hs_prefix = data.get("hs_prefix", "")
        rule      = data.get("rule", {})
        if hs_prefix and rule:
            from_c, to_c = route.split("-") if "-" in route else ("IN", "AE")
            profile = RouteMemoryProfile(self.store, from_c, to_c)
            await profile.learn_compliance_rule(hs_prefix, rule)


# ─────────────────────────────────────────────
# SIMPLE LOCAL EMBEDDER (no API key needed)
# Replace with OpenAI ada-002 in production
# ─────────────────────────────────────────────

class LocalEmbedder:
    """
    Sentence-transformers local embedder.
    No API cost. Fast. Good enough for intra-org memory.
    Production: swap to OpenAI ada-002 for higher quality.
    """

    def __init__(self, model_name: str = "all-MiniLM-L6-v2"):
        self._model = None
        self._model_name = model_name

    def _load(self):
        if self._model is None:
            from sentence_transformers import SentenceTransformer
            self._model = SentenceTransformer(self._model_name)

    async def embed(self, text: str) -> list[float]:
        self._load()
        import asyncio
        loop = asyncio.get_event_loop()
        vec  = await loop.run_in_executor(None, self._model.encode, text)
        return vec.tolist()

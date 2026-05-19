"""
TradeOS — FastAPI Backend Service
==================================
Async · Multi-tenant · Event-driven
All agents are modular and LLM-provider-agnostic.
"""

from __future__ import annotations

import asyncio
import json
import os
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timedelta
from typing import Any

import httpx
from fastapi import (
    BackgroundTasks, Depends, FastAPI, File, HTTPException,
    Request, UploadFile, WebSocket, WebSocketDisconnect, status,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field


# ─────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────

class Settings:
    APP_NAME = "TradeOS API"
    VERSION  = "0.1.0"

    # Database
    DATABASE_URL = "postgresql+asyncpg://tradeos:secret@localhost/tradeos"

    # LLM Provider chain (tried in order, with fallback)
    LLM_CHAIN = [
        {"provider": "openai",    "model": "gpt-4o",           "priority": 1},
        {"provider": "grok",      "model": "grok-4",           "priority": 2},
        {"provider": "anthropic", "model": "claude-opus-4-6",  "priority": 3},
        {"provider": "gemini",    "model": "gemini-2.0-flash",  "priority": 4},
        {"provider": "local",     "model": "mistral-7b-q4",    "priority": 5},
    ]

    # Workflow
    TEMPORAL_HOST   = "localhost:7233"
    KAFKA_BOOTSTRAP = "localhost:9092"

    # Storage
    S3_BUCKET = "tradeos-documents"

    # WhatsApp
    WHATSAPP_PROVIDER   = "meta"  # meta | twilio
    WHATSAPP_API_URL    = "https://graph.facebook.com/v18.0"
    WHATSAPP_TOKEN      = ""  # from env
    WHATSAPP_PHONE_ID   = ""  # from env
    WHATSAPP_VERIFY_TOKEN = ""
    TWILIO_ACCOUNT_SID  = ""
    TWILIO_AUTH_TOKEN   = ""
    TWILIO_PHONE_NUMBER = ""

    # Auth
    JWT_SECRET      = ""  # from env
    JWT_EXPIRE_MINS = 60 * 8

    # HITL
    CONFIDENCE_THRESHOLD_AUTO   = 92.0   # above this → auto-approve
    CONFIDENCE_THRESHOLD_HUMAN  = 70.0   # below this → mandatory human review
    APPROVAL_TIMEOUT_HOURS      = 4


cfg = Settings()


# ─────────────────────────────────────────────
# PYDANTIC MODELS
# ─────────────────────────────────────────────

class OrgContext(BaseModel):
    org_id: uuid.UUID
    user_id: uuid.UUID
    role: str


class POIngestRequest(BaseModel):
    """Ingest a purchase order from any source."""
    source: str = Field(..., description="whatsapp | email | portal | manual")
    raw_text: str | None = None
    buyer_contact_id: uuid.UUID | None = None
    metadata: dict = Field(default_factory=dict)


class ExtractionResult(BaseModel):
    buyer_name: str | None
    buyer_country: str | None
    items: list[dict]           # [{description, quantity, unit, unit_price, hs_code}]
    currency: str
    payment_terms: str | None
    destination_port: str | None
    incoterms: str | None
    delivery_date: str | None
    special_instructions: str | None
    confidence: float
    warnings: list[str] = []


class DocumentGenerationRequest(BaseModel):
    order_id: uuid.UUID
    doc_types: list[str]        # ["commercial_invoice", "packing_list", ...]
    overrides: dict = Field(default_factory=dict)


class ApprovalAction(BaseModel):
    action: str = Field(..., pattern="^(approve|reject|request_changes)$")
    note: str | None = None
    field_overrides: dict = Field(default_factory=dict)  # for partial approval


class WhatsAppWebhookPayload(BaseModel):
    object: str
    entry: list[dict]


class MemoryUpsertRequest(BaseModel):
    agent_name: str
    memory_type: str
    scope_type: str
    scope_id: uuid.UUID | None
    key: str
    value: Any
    confidence: float = 50.0


# ─────────────────────────────────────────────
# LLM ROUTER — provider-agnostic
# ─────────────────────────────────────────────

class LLMRouter:
    """
    Tries providers in priority order.
    Falls back automatically on error or low confidence.
    NEVER couple business logic to a specific model.
    """

    @staticmethod
    async def complete(
        system_prompt: str,
        user_prompt: str,
        output_schema: dict | None = None,
        max_tokens: int = 2000,
        temperature: float = 0.1,
    ) -> dict:
        errors = []
        for provider_cfg in sorted(cfg.LLM_CHAIN, key=lambda x: x["priority"]):
            try:
                result = await LLMRouter._call_provider(
                    provider_cfg, system_prompt, user_prompt,
                    output_schema, max_tokens, temperature
                )
                result["provider_used"] = provider_cfg["provider"]
                return result
            except Exception as e:
                errors.append(f"{provider_cfg['provider']}: {e}")
                continue
        raise RuntimeError(f"All LLM providers failed: {errors}")

    @staticmethod
    async def _call_provider(
        provider_cfg: dict,
        system_prompt: str,
        user_prompt: str,
        output_schema: dict | None,
        max_tokens: int,
        temperature: float,
    ) -> dict:
        provider = provider_cfg["provider"]
        model    = provider_cfg["model"]

        if output_schema:
            user_prompt += (
                "\n\nRespond ONLY with valid JSON matching this schema:"
                f"\n{json.dumps(output_schema, indent=2)}"
            )

        if provider == "openai":
            return await LLMRouter._openai(model, system_prompt, user_prompt, max_tokens, temperature)
        elif provider == "grok":
            return await LLMRouter._grok(model, system_prompt, user_prompt, max_tokens, temperature)
        elif provider == "anthropic":
            return await LLMRouter._anthropic(model, system_prompt, user_prompt, max_tokens, temperature)
        elif provider == "gemini":
            return await LLMRouter._gemini(model, system_prompt, user_prompt, max_tokens, temperature)
        elif provider == "local":
            return await LLMRouter._local(model, system_prompt, user_prompt, max_tokens, temperature)
        else:
            raise ValueError(f"Unknown provider: {provider}")

    @staticmethod
    async def _anthropic(model, system, user, max_tokens, temperature) -> dict:
        import os
        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "x-api-key": os.getenv("ANTHROPIC_API_KEY", ""),
                    "anthropic-version": "2023-06-01",
                    "content-type": "application/json",
                },
                json={
                    "model": model,
                    "max_tokens": max_tokens,
                    "temperature": temperature,
                    "system": system,
                    "messages": [{"role": "user", "content": user}],
                },
            )
            resp.raise_for_status()
            data = resp.json()
            return {"text": data["content"][0]["text"]}

    @staticmethod
    async def _openai(model, system, user, max_tokens, temperature) -> dict:
        import os
        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.post(
                "https://api.openai.com/v1/chat/completions",
                headers={"Authorization": f"Bearer {os.getenv('OPENAI_API_KEY','')}"},
                json={
                    "model": model,
                    "max_tokens": max_tokens,
                    "temperature": temperature,
                    "messages": [
                        {"role": "system", "content": system},
                        {"role": "user",   "content": user},
                    ],
                },
            )
            resp.raise_for_status()
            data = resp.json()
            return {"text": data["choices"][0]["message"]["content"]}

    @staticmethod
    async def _grok(model, system, user, max_tokens, temperature) -> dict:
        import os
        base_url = os.getenv("XAI_BASE_URL", "https://api.x.ai/v1").rstrip("/")
        async with httpx.AsyncClient(timeout=120) as client:
            resp = await client.post(
                f"{base_url}/chat/completions",
                headers={"Authorization": f"Bearer {os.getenv('XAI_API_KEY','')}"},
                json={
                    "model": os.getenv("XAI_MODEL", model),
                    "max_tokens": max_tokens,
                    "temperature": temperature,
                    "messages": [
                        {"role": "system", "content": system},
                        {"role": "user",   "content": user},
                    ],
                },
            )
            resp.raise_for_status()
            data = resp.json()
            return {"text": data["choices"][0]["message"]["content"]}

    @staticmethod
    async def _gemini(model, system, user, max_tokens, temperature) -> dict:
        import os
        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.post(
                f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
                params={"key": os.getenv("GEMINI_API_KEY", "")},
                json={
                    "contents": [{"parts": [{"text": f"{system}\n\n{user}"}]}],
                    "generationConfig": {"maxOutputTokens": max_tokens, "temperature": temperature},
                },
            )
            resp.raise_for_status()
            data = resp.json()
            return {"text": data["candidates"][0]["content"]["parts"][0]["text"]}

    @staticmethod
    async def _local(model, system, user, max_tokens, temperature) -> dict:
        async with httpx.AsyncClient(timeout=120) as client:
            resp = await client.post(
                "http://localhost:11434/api/chat",
                json={
                    "model": model,
                    "messages": [
                        {"role": "system", "content": system},
                        {"role": "user",   "content": user},
                    ],
                    "stream": False,
                    "options": {"num_predict": max_tokens, "temperature": temperature},
                },
            )
            resp.raise_for_status()
            return {"text": resp.json()["message"]["content"]}


# ─────────────────────────────────────────────
# AGENT BASE
# ─────────────────────────────────────────────

class BaseAgent:
    """All agents inherit from here. Stateless. LLM-agnostic."""

    name: str = "base_agent"

    def __init__(self, org_id: uuid.UUID, db=None, memory_store=None):
        self.org_id       = org_id
        self.db           = db
        self.memory       = memory_store
        self.llm          = LLMRouter()

    async def run(self, input_data: dict) -> dict:
        raise NotImplementedError

    async def _remember(self, key: str, value: Any, memory_type: str,
                        scope_type: str = "org", scope_id: uuid.UUID | None = None,
                        confidence: float = 80.0):
        """Store observation in agent memory layer."""
        # In production: upsert to agent_memory table + update embedding
        pass

    async def _recall(self, query: str, memory_type: str | None = None, top_k: int = 5) -> list[dict]:
        """Semantic recall from agent memory."""
        # In production: vector similarity search on agent_memory table
        return []

    def _emit_event(self, event_type: str, payload: dict):
        """Emit to Kafka event bus (non-blocking)."""
        # kafka_producer.send(f"tradeos.{event_type}", payload)
        pass


# ─────────────────────────────────────────────
# DOCUMENT INTELLIGENCE ENGINE
# ─────────────────────────────────────────────

class DocumentIntelligenceEngine:
    """
    Core IP layer.
    OCR → Table extraction → Structured parsing → Validation.
    """

    @staticmethod
    async def extract_from_file(file_bytes: bytes, mime_type: str) -> dict:
        """Multi-modal extraction pipeline."""
        # Step 1: OCR (PaddleOCR / Azure Document Intelligence)
        raw_text = await DocumentIntelligenceEngine._ocr(file_bytes, mime_type)

        # Step 2: Table detection
        tables   = await DocumentIntelligenceEngine._extract_tables(raw_text)

        # Step 3: Signature/stamp detection (vision model)
        stamps   = await DocumentIntelligenceEngine._detect_stamps(file_bytes)

        # Step 4: LLM structured extraction
        extracted = await DocumentIntelligenceEngine._llm_extract(raw_text, tables)

        return {
            "raw_text": raw_text,
            "tables":   tables,
            "stamps":   stamps,
            "extracted": extracted,
        }

    @staticmethod
    async def _ocr(file_bytes: bytes, mime_type: str) -> str:
        """PaddleOCR → correction LLM pass for low-confidence tokens."""
        # Production: call PaddleOCR service, then correction pass
        return "[OCR output placeholder]"

    @staticmethod
    async def _extract_tables(text: str) -> list[dict]:
        """Detect and parse tabular structures from OCR output."""
        result = await LLMRouter.complete(
            system_prompt=(
                "You are a document parser specialized in trade documents. "
                "Extract all table structures as JSON arrays. "
                "Handle merged cells, rotated headers, and partial columns."
            ),
            user_prompt=f"Extract tables from this document text:\n\n{text}",
            output_schema={"tables": [{"headers": [], "rows": []}]},
            temperature=0.0,
        )
        try:
            return json.loads(result["text"]).get("tables", [])
        except Exception:
            return []

    @staticmethod
    async def _detect_stamps(file_bytes: bytes) -> dict:
        """Vision model for stamp/signature detection."""
        return {"has_signature": None, "has_stamp": None, "stamp_text": None}

    @staticmethod
    async def _llm_extract(text: str, tables: list) -> dict:
        result = await LLMRouter.complete(
            system_prompt=(
                "You are an expert in international trade documentation. "
                "Extract all relevant fields from export/import documents. "
                "For HS codes, always include your confidence (0-100). "
                "Normalize quantities to standard units."
            ),
            user_prompt=(
                f"Document text:\n{text}\n\nTables:\n{json.dumps(tables)}"
                "\n\nExtract all fields."
            ),
            output_schema={
                "doc_type": "string",
                "reference_number": "string",
                "date": "string",
                "parties": {
                    "exporter": {"name": "", "address": "", "iec": ""},
                    "importer": {"name": "", "address": ""},
                },
                "items": [{
                    "description": "",
                    "hs_code": "",
                    "hs_confidence": 0,
                    "quantity": 0,
                    "unit": "",
                    "unit_price": 0,
                    "total_value": 0,
                    "country_of_origin": "",
                }],
                "total_value": 0,
                "currency": "",
                "payment_terms": "",
                "incoterms": "",
                "special_conditions": [],
                "overall_confidence": 0,
                "extraction_warnings": [],
            },
            temperature=0.0,
        )
        try:
            return json.loads(result["text"])
        except Exception:
            return {}


# ─────────────────────────────────────────────
# AGENTS
# ─────────────────────────────────────────────

class POExtractionAgent(BaseAgent):
    name = "po_extraction_agent"

    SYSTEM_PROMPT = """
You are an expert in international trade purchase orders.
Extract structured data from any PO format: PDF, WhatsApp message, email body, or scanned image.
Handle Arabic, English, Hindi. Normalize all values.
Always output confidence score 0-100 per field and overall.
Flag ambiguous fields as warnings, do not hallucinate.
"""

    async def run(self, input_data: dict) -> dict:
        source   = input_data["source"]       # "whatsapp" | "email" | "file"
        raw_text = input_data.get("raw_text", "")

        # Recall: does this buyer have patterns we've seen before?
        buyer_memories = []
        if input_data.get("buyer_contact_id"):
            buyer_memories = await self._recall(
                query="buyer purchase order patterns",
                memory_type="customer_preference",
            )

        memory_context = (
            f"\nKnown buyer patterns: {json.dumps(buyer_memories)}" if buyer_memories else ""
        )

        result = await self.llm.complete(
            system_prompt=self.SYSTEM_PROMPT + memory_context,
            user_prompt=f"Source: {source}\n\nContent:\n{raw_text}",
            output_schema={
                "buyer_name": "string",
                "buyer_country": "string",
                "items": [{
                    "description": "string",
                    "quantity": 0,
                    "unit": "string",
                    "unit_price": 0,
                    "hs_code": "string",
                    "hs_confidence": 0,
                }],
                "currency": "string",
                "payment_terms": "string",
                "destination_port": "string",
                "incoterms": "string",
                "delivery_date": "string",
                "special_instructions": "string",
                "confidence": 0,
                "warnings": [],
            },
            temperature=0.0,
        )

        extracted = json.loads(result["text"])

        # Learn: update buyer memory with this pattern
        await self._remember(
            key="last_po_pattern",
            value={"items": extracted.get("items", []), "currency": extracted.get("currency")},
            memory_type="customer_preference",
            scope_type="contact",
        )

        self._emit_event("po.extracted", {
            "org_id": str(self.org_id),
            "confidence": extracted.get("confidence"),
            "item_count": len(extracted.get("items", [])),
        })

        return {"status": "ok", "data": extracted, "provider": result.get("provider_used")}


class HSCodeValidationAgent(BaseAgent):
    name = "hs_validation_agent"

    SYSTEM_PROMPT = """
You are an international trade compliance expert specializing in HS (Harmonized System) codes.
Validate HS codes against the official WCO schedule.
For each code: verify description match, check for country-specific restrictions,
flag prohibited/restricted categories, suggest corrections if wrong.
Consider both the 6-digit WCO code and country-specific extensions (8-digit for India, UAE).
"""

    async def run(self, input_data: dict) -> dict:
        items            = input_data["items"]
        from_country     = input_data.get("from_country", "IN")
        to_country       = input_data.get("to_country", "AE")

        # Recall previously validated HS codes for this org
        cached_codes = await self._recall(
            query=" ".join(i.get("description", "") for i in items),
            memory_type="hs_code_learned",
        )

        result = await self.llm.complete(
            system_prompt=self.SYSTEM_PROMPT,
            user_prompt=(
                f"Validate these items for export from {from_country} to {to_country}:\n"
                f"{json.dumps(items, indent=2)}\n"
                f"Previously validated codes for this org: {json.dumps(cached_codes)}"
            ),
            output_schema={
                "validations": [{
                    "original_description": "string",
                    "original_hs_code": "string",
                    "validated_hs_code": "string",
                    "is_valid": True,
                    "confidence": 0,
                    "description_match": True,
                    "restrictions": [],
                    "correction_reason": "string",
                    "dgft_schedule": "string",
                    "import_duty_destination": 0,
                }],
                "overall_clearance": True,
                "flags": [],
            },
            temperature=0.0,
        )

        data = json.loads(result["text"])

        # Learn validated codes
        for v in data.get("validations", []):
            if v.get("is_valid") and v.get("confidence", 0) > 85:
                await self._remember(
                    key=v["validated_hs_code"],
                    value={"description": v["original_description"], "route": f"{from_country}-{to_country}"},
                    memory_type="hs_code_learned",
                    confidence=v["confidence"],
                )

        return {"status": "ok", "data": data}


class DocumentGenerationAgent(BaseAgent):
    name = "doc_generation_agent"

    async def run(self, input_data: dict) -> dict:
        doc_type  = input_data["doc_type"]
        order     = input_data["order"]
        overrides = input_data.get("overrides", {})

        # Recall: does this buyer have a preferred invoice format?
        style_memory = await self._recall(
            query="invoice format preference",
            memory_type="invoice_style",
        )

        generators = {
            "commercial_invoice": self._gen_commercial_invoice,
            "packing_list":       self._gen_packing_list,
            "certificate_of_origin": self._gen_coo,
            "bill_of_lading":     self._gen_bl_draft,
        }

        if doc_type not in generators:
            raise ValueError(f"Unsupported doc type: {doc_type}")

        doc_data  = await generators[doc_type](order, overrides, style_memory)

        return {
            "status":      "ok",
            "doc_type":    doc_type,
            "doc_data":    doc_data,
            "confidence":  doc_data.get("_confidence", 95),
        }

    async def _gen_commercial_invoice(self, order: dict, overrides: dict, style: list) -> dict:
        result = await self.llm.complete(
            system_prompt=(
                "Generate a complete commercial invoice for international export. "
                "Follow UNCTAD/ICC standards. Include all mandatory fields for LC documentation. "
                "Apply Indian GST zero-rating for exports (LUT). "
                "Format amounts correctly for the destination country."
            ),
            user_prompt=(
                f"Generate commercial invoice for:\n{json.dumps(order, indent=2)}"
                f"\nOverrides: {json.dumps(overrides)}"
                f"\nBuyer style preferences: {json.dumps(style)}"
            ),
            output_schema={
                "invoice_number": "string",
                "invoice_date": "string",
                "exporter": {"name": "", "address": "", "iec": "", "gstin": ""},
                "importer": {"name": "", "address": "", "vat": ""},
                "items": [{"description": "", "hs_code": "", "qty": 0, "unit": "", "unit_price": 0, "total": 0}],
                "subtotal": 0,
                "freight_charges": 0,
                "insurance": 0,
                "grand_total": 0,
                "currency": "",
                "payment_terms": "",
                "incoterms": "",
                "bank_details": {},
                "declaration": "string",
                "_confidence": 0,
            },
            temperature=0.0,
        )
        return json.loads(result["text"])

    async def _gen_packing_list(self, order: dict, overrides: dict, style: list) -> dict:
        result = await self.llm.complete(
            system_prompt="Generate a detailed packing list for international export.",
            user_prompt=f"Order data:\n{json.dumps(order, indent=2)}",
            output_schema={
                "pl_number": "string",
                "packages": [{"pkg_no": 0, "description": "", "qty": 0, "net_wt_kg": 0, "gross_wt_kg": 0, "dims_cm": ""}],
                "total_packages": 0,
                "total_net_weight_kg": 0,
                "total_gross_weight_kg": 0,
                "total_volume_cbm": 0,
                "_confidence": 0,
            },
            temperature=0.0,
        )
        return json.loads(result["text"])

    async def _gen_coo(self, order: dict, overrides: dict, style: list) -> dict:
        result = await self.llm.complete(
            system_prompt="Generate a Certificate of Origin for international export.",
            user_prompt=f"Order data:\n{json.dumps(order, indent=2)}",
            output_schema={"_confidence": 0},
            temperature=0.0,
        )
        return json.loads(result["text"])

    async def _gen_bl_draft(self, order: dict, overrides: dict, style: list) -> dict:
        return {"_confidence": 90, "status": "draft"}


class HITLOrchestrator:
    """
    Human-In-The-Loop decision engine.
    Determines: auto-approve | flag for human | block.
    """

    @staticmethod
    def evaluate(step_name: str, confidence: float, risk_flags: list) -> dict:
        critical_flags = [f for f in risk_flags if f.get("severity") == "critical"]
        high_flags     = [f for f in risk_flags if f.get("severity") == "high"]

        if critical_flags:
            return {
                "decision": "block",
                "reason":   f"Critical flags: {[f['message'] for f in critical_flags]}",
                "requires_human": True,
            }

        if confidence >= cfg.CONFIDENCE_THRESHOLD_AUTO and not high_flags:
            return {
                "decision": "auto_approve",
                "reason":   f"Confidence {confidence:.1f}% above threshold, no high-severity flags",
                "requires_human": False,
            }

        if confidence < cfg.CONFIDENCE_THRESHOLD_HUMAN or high_flags:
            return {
                "decision": "require_human",
                "reason":   (
                    f"Confidence {confidence:.1f}% below threshold" if confidence < cfg.CONFIDENCE_THRESHOLD_HUMAN
                    else f"High-severity flags: {[f['message'] for f in high_flags]}"
                ),
                "requires_human": True,
            }

        return {
            "decision": "soft_review",
            "reason":   "Moderate confidence — flagging for optional review",
            "requires_human": True,
        }

    @staticmethod
    def compute_diff(before: dict, after: dict) -> list[dict]:
        """Field-level diff for the approval UI."""
        diffs = []
        all_keys = set(before.keys()) | set(after.keys())
        for key in all_keys:
            b, a = before.get(key), after.get(key)
            if b != a:
                diffs.append({"field": key, "before": b, "after": a})
        return diffs


# ─────────────────────────────────────────────
# WHATSAPP INTEGRATION
# ─────────────────────────────────────────────

class WhatsAppService:

    @staticmethod
    async def send_text(to: str, body: str) -> dict:
        provider = os.getenv("WHATSAPP_PROVIDER", cfg.WHATSAPP_PROVIDER).lower()
        if provider == "twilio":
            return await WhatsAppService._send_twilio_text(to, body)
        return await WhatsAppService._send_meta_text(to, body)

    @staticmethod
    async def send_document(to: str, doc_url: str, filename: str, caption: str = "") -> dict:
        provider = os.getenv("WHATSAPP_PROVIDER", cfg.WHATSAPP_PROVIDER).lower()
        if provider == "twilio":
            return await WhatsAppService._send_twilio_document(to, doc_url, filename, caption)
        return await WhatsAppService._send_meta_document(to, doc_url, filename, caption)

    @staticmethod
    async def _send_meta_text(to: str, body: str) -> dict:
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{cfg.WHATSAPP_API_URL}/{os.getenv('WHATSAPP_PHONE_ID')}/messages",
                headers={"Authorization": f"Bearer {os.getenv('WHATSAPP_TOKEN')}"},
                json={
                    "messaging_product": "whatsapp",
                    "to": to,
                    "type": "text",
                    "text": {"body": body},
                },
            )
            resp.raise_for_status()
            return resp.json()

    @staticmethod
    async def _send_meta_document(to: str, doc_url: str, filename: str, caption: str = "") -> dict:
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{cfg.WHATSAPP_API_URL}/{os.getenv('WHATSAPP_PHONE_ID')}/messages",
                headers={"Authorization": f"Bearer {os.getenv('WHATSAPP_TOKEN')}"},
                json={
                    "messaging_product": "whatsapp",
                    "to": to,
                    "type": "document",
                    "document": {"link": doc_url, "filename": filename, "caption": caption},
                },
            )
            resp.raise_for_status()
            return resp.json()

    @staticmethod
    async def _send_twilio_text(to: str, body: str) -> dict:
        account_sid = WhatsAppService._env("TWILIO_ACCOUNT_SID")
        auth_token = WhatsAppService._env("TWILIO_AUTH_TOKEN")
        from_number = WhatsAppService._twilio_whatsapp_number(
            WhatsAppService._env("TWILIO_PHONE_NUMBER")
        )

        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"https://api.twilio.com/2010-04-01/Accounts/{account_sid}/Messages.json",
                auth=(account_sid, auth_token),
                data={
                    "From": from_number,
                    "To": WhatsAppService._twilio_whatsapp_number(to),
                    "Body": body,
                },
            )
            resp.raise_for_status()
            return resp.json()

    @staticmethod
    async def _send_twilio_document(to: str, doc_url: str, filename: str, caption: str = "") -> dict:
        account_sid = WhatsAppService._env("TWILIO_ACCOUNT_SID")
        auth_token = WhatsAppService._env("TWILIO_AUTH_TOKEN")
        from_number = WhatsAppService._twilio_whatsapp_number(
            WhatsAppService._env("TWILIO_PHONE_NUMBER")
        )
        body = caption or filename

        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"https://api.twilio.com/2010-04-01/Accounts/{account_sid}/Messages.json",
                auth=(account_sid, auth_token),
                data={
                    "From": from_number,
                    "To": WhatsAppService._twilio_whatsapp_number(to),
                    "Body": body,
                    "MediaUrl": doc_url,
                },
            )
            resp.raise_for_status()
            return resp.json()

    @staticmethod
    def parse_meta_inbound(payload: dict) -> list[dict]:
        """Parse Meta WhatsApp webhook → list of message dicts."""
        messages = []
        for entry in payload.get("entry", []):
            for change in entry.get("changes", []):
                value = change.get("value", {})
                for msg in value.get("messages", []):
                    messages.append({
                        "from":      msg.get("from"),
                        "wa_msg_id": msg.get("id"),
                        "type":      msg.get("type"),
                        "text":      msg.get("text", {}).get("body", ""),
                        "timestamp": msg.get("timestamp"),
                        "contact":   value.get("contacts", [{}])[0],
                    })
        return messages

    @staticmethod
    def parse_twilio_inbound(form: dict) -> list[dict]:
        """Parse Twilio WhatsApp webhook form data → list of message dicts."""
        text = form.get("Body", "")
        media_urls = [
            form.get(f"MediaUrl{i}")
            for i in range(int(form.get("NumMedia", "0") or 0))
            if form.get(f"MediaUrl{i}")
        ]
        return [{
            "from": WhatsAppService._strip_twilio_whatsapp_prefix(form.get("From", "")),
            "wa_msg_id": form.get("MessageSid") or form.get("SmsSid"),
            "type": "document" if media_urls else "text",
            "text": text,
            "timestamp": datetime.utcnow().isoformat(),
            "contact": {
                "profile": {"name": form.get("ProfileName", "")},
                "wa_id": WhatsAppService._strip_twilio_whatsapp_prefix(form.get("WaId", "")),
            },
            "media_urls": media_urls,
            "provider": "twilio",
        }]

    @staticmethod
    def _twilio_whatsapp_number(number: str) -> str:
        if number.startswith("whatsapp:"):
            return number
        return f"whatsapp:{number}"

    @staticmethod
    def _strip_twilio_whatsapp_prefix(number: str) -> str:
        return number.removeprefix("whatsapp:")

    @staticmethod
    def _env(name: str) -> str:
        # Backward compatible with the current env typo: TWIlIO_*.
        legacy_name = name.replace("TWILIO", "TWIlIO")
        value = os.getenv(name) or os.getenv(legacy_name) or getattr(cfg, name, "")
        if not value:
            raise RuntimeError(f"{name} is required for Twilio WhatsApp")
        return value


# ─────────────────────────────────────────────
# KILLER DEMO WORKFLOW
# End-to-end: PO → Invoice → HS Check → HITL → Send
# ─────────────────────────────────────────────

class KillerDemoWorkflow:
    """
    The workflow that closes deals.
    PO (PDF/WhatsApp) → Extract → Validate HS → Generate Docs
    → HITL Decision → Approve → Send via WhatsApp/Email → Track
    """

    def __init__(self, org_id: uuid.UUID, db=None):
        self.org_id = org_id
        self.db     = db

    async def execute(
        self,
        source: str,
        raw_text: str | None = None,
        file_bytes: bytes | None = None,
        buyer_whatsapp: str | None = None,
        buyer_email: str | None = None,
    ) -> dict:

        steps_log = []

        def log(step: str, status: str, data: dict | None = None):
            entry = {"step": step, "status": status, "ts": datetime.utcnow().isoformat(), "data": data or {}}
            steps_log.append(entry)
            return entry

        # ── STEP 1: EXTRACT PO ────────────────────────────
        log("po_extraction", "running")
        agent = POExtractionAgent(self.org_id)

        if file_bytes:
            doc_intel = await DocumentIntelligenceEngine.extract_from_file(
                file_bytes, "application/pdf"
            )
            raw_text = doc_intel["raw_text"]

        extraction = await agent.run({"source": source, "raw_text": raw_text or ""})
        extracted  = extraction["data"]
        log("po_extraction", "done", {"confidence": extracted.get("confidence"), "items": len(extracted.get("items", []))})

        # ── STEP 2: HS CODE VALIDATION ────────────────────
        log("hs_validation", "running")
        hs_agent  = HSCodeValidationAgent(self.org_id)
        hs_result = await hs_agent.run({
            "items": extracted.get("items", []),
            "from_country": "IN",
            "to_country":   extracted.get("buyer_country", "AE")[:2].upper() if extracted.get("buyer_country") else "AE",
        })
        hs_data = hs_result["data"]
        risk_flags = [
            {"message": f, "severity": "high"}
            for f in hs_data.get("flags", [])
        ]
        log("hs_validation", "done", {"clearance": hs_data.get("overall_clearance"), "flags": len(risk_flags)})

        # ── STEP 3: GENERATE DOCUMENTS ────────────────────
        log("doc_generation", "running")
        doc_agent = DocumentGenerationAgent(self.org_id)
        order_data = {
            "buyer":    extracted.get("buyer_name"),
            "country":  extracted.get("buyer_country"),
            "items":    hs_data.get("validations", []),
            "currency": extracted.get("currency", "USD"),
            "terms":    extracted.get("payment_terms"),
            "incoterms": extracted.get("incoterms"),
            "port":     extracted.get("destination_port"),
        }

        invoice_result  = await doc_agent.run({"doc_type": "commercial_invoice", "order": order_data})
        packing_result  = await doc_agent.run({"doc_type": "packing_list",       "order": order_data})
        invoice_data    = invoice_result["doc_data"]
        overall_confidence = min(
            extracted.get("confidence", 80),
            invoice_result.get("confidence", 80),
        )
        log("doc_generation", "done", {"docs": ["commercial_invoice", "packing_list"], "confidence": overall_confidence})

        # ── STEP 4: HITL DECISION ─────────────────────────
        log("hitl_evaluation", "running")
        hitl_decision = HITLOrchestrator.evaluate(
            "doc_generation",
            overall_confidence,
            risk_flags,
        )
        log("hitl_evaluation", "done", hitl_decision)

        approval_required = hitl_decision["requires_human"]
        approval_id       = str(uuid.uuid4()) if approval_required else None

        # ── STEP 5: SEND NOTIFICATION ─────────────────────
        if approval_required:
            # Pause here — system waits for human action
            log("awaiting_human", "paused", {
                "approval_id": approval_id,
                "decision":    hitl_decision["decision"],
                "reason":      hitl_decision["reason"],
                "confidence":  overall_confidence,
            })
        else:
            # Auto-approved — dispatch immediately
            log("dispatch", "running")
            if buyer_whatsapp:
                await WhatsAppService.send_text(
                    to=buyer_whatsapp,
                    body=(
                        f"✅ Your order has been confirmed and documents are ready.\n\n"
                        f"Order: {invoice_data.get('invoice_number', 'N/A')}\n"
                        f"Amount: {invoice_data.get('currency')} {invoice_data.get('grand_total')}\n"
                        f"Terms: {invoice_data.get('payment_terms')}\n"
                        f"ETA: 3 working days\n\n"
                        f"Documents will follow shortly. Thank you! 🚢"
                    )
                )
            log("dispatch", "done", {"channel": "whatsapp"})

        return {
            "workflow_id":       str(uuid.uuid4()),
            "status":            "awaiting_approval" if approval_required else "completed",
            "approval_id":       approval_id,
            "hitl_decision":     hitl_decision,
            "overall_confidence": overall_confidence,
            "steps":             steps_log,
            "extracted_order":   extracted,
            "hs_validation":     hs_data,
            "documents": {
                "commercial_invoice": invoice_data,
                "packing_list":       packing_result["doc_data"],
            },
            "risk_flags": risk_flags,
        }


# ─────────────────────────────────────────────
# FASTAPI APP
# ─────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    # startup
    print("🚀 TradeOS API starting — connecting to DB, Kafka, Temporal…")
    yield
    # shutdown
    print("🛑 TradeOS API shutting down…")


app = FastAPI(
    title=cfg.APP_NAME,
    version=cfg.VERSION,
    description="Agentic AI OS for Export Documentation — Async · Multi-tenant · Event-driven",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Dependency: org context from JWT ──────────
async def get_org_context(request: Request) -> OrgContext:
    """
    In production: validate JWT, extract org_id + user_id + role.
    Enforce row-level security for all DB queries using org_id.
    """
    return OrgContext(
        org_id=uuid.UUID("00000000-0000-0000-0000-000000000001"),
        user_id=uuid.UUID("00000000-0000-0000-0000-000000000002"),
        role="operator",
    )


# ─────────────────────────────────────────────
# ROUTES
# ─────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "ok", "version": cfg.VERSION, "service": cfg.APP_NAME}


# ── KILLER DEMO: Full workflow ────────────────

@app.post("/api/v1/workflow/po-to-dispatch")
async def run_killer_demo(
    background_tasks: BackgroundTasks,
    po_text: str | None = None,
    buyer_whatsapp: str | None = None,
    buyer_email: str | None = None,
    file: UploadFile | None = File(None),
    ctx: OrgContext = Depends(get_org_context),
):
    """
    THE KILLER DEMO ENDPOINT.
    Feed it a PO (text or PDF) and it runs the full pipeline:
    Extract → HS Validate → Generate Invoice + Packing List
    → HITL decision → Send WhatsApp/Email → Return full result.
    """
    file_bytes = await file.read() if file else None

    workflow = KillerDemoWorkflow(org_id=ctx.org_id)
    result   = await workflow.execute(
        source="whatsapp" if not file else "file",
        raw_text=po_text,
        file_bytes=file_bytes,
        buyer_whatsapp=buyer_whatsapp,
        buyer_email=buyer_email,
    )
    return result


# ── WHATSAPP ──────────────────────────────────

@app.get("/api/v1/webhooks/whatsapp")
async def whatsapp_verify(
    hub_mode: str | None = None,
    hub_challenge: str | None = None,
    hub_verify_token: str | None = None,
):
    """WhatsApp webhook verification handshake."""
    verify_token = os.getenv("WHATSAPP_VERIFY_TOKEN", cfg.WHATSAPP_VERIFY_TOKEN)
    if hub_mode == "subscribe" and hub_verify_token == verify_token:
        return int(hub_challenge)
    raise HTTPException(status_code=403, detail="Verification failed")


@app.post("/api/v1/webhooks/whatsapp")
async def whatsapp_inbound(
    payload: WhatsAppWebhookPayload,
    background_tasks: BackgroundTasks,
):
    """Receive inbound WhatsApp messages → trigger workflow."""
    messages = WhatsAppService.parse_meta_inbound(payload.model_dump())
    for msg in messages:
        # Async: don't block the webhook response
        background_tasks.add_task(
            _process_inbound_whatsapp,
            msg,
            org_id=uuid.UUID("00000000-0000-0000-0000-000000000001"),  # resolve from phone
        )
    return {"status": "received"}


@app.post("/api/v1/webhooks/twilio/whatsapp")
async def twilio_whatsapp_inbound(
    request: Request,
    background_tasks: BackgroundTasks,
):
    """Receive inbound Twilio WhatsApp messages → trigger workflow."""
    form = dict(await request.form())
    messages = WhatsAppService.parse_twilio_inbound(form)
    for msg in messages:
        background_tasks.add_task(
            _process_inbound_whatsapp,
            msg,
            org_id=uuid.UUID("00000000-0000-0000-0000-000000000001"),  # resolve from phone
        )
    return {"status": "received"}


async def _process_inbound_whatsapp(msg: dict, org_id: uuid.UUID):
    """Background task: process inbound WhatsApp → extract PO → run workflow."""
    text = msg.get("text", "")
    if not text:
        return

    workflow = KillerDemoWorkflow(org_id=org_id)
    result   = await workflow.execute(
        source="whatsapp",
        raw_text=text,
        buyer_whatsapp=msg.get("from"),
    )

    # If auto-approved, docs already sent.
    # If awaiting human, approval_requests table was written.
    # Emit to Kafka for downstream consumers.
    print(f"[WA workflow] status={result['status']} confidence={result['overall_confidence']}")


# ── HITL APPROVALS ───────────────────────────

@app.get("/api/v1/approvals")
async def list_approvals(ctx: OrgContext = Depends(get_org_context)):
    """Fetch all pending approval requests for this org."""
    # In production: query approval_requests WHERE org_id=ctx.org_id AND status='pending'
    return {"approvals": [], "total": 0}


@app.post("/api/v1/approvals/{approval_id}/action")
async def action_approval(
    approval_id: uuid.UUID,
    body: ApprovalAction,
    ctx: OrgContext = Depends(get_org_context),
):
    """
    Human approves / rejects / requests changes.
    Resumes the paused Temporal workflow.
    Writes full audit trail.
    """
    # 1. Fetch approval_request
    # 2. Validate user has permission (RBAC)
    # 3. Write audit_log entry
    # 4. Update approval status
    # 5. Signal Temporal workflow to resume
    # 6. If approved + field_overrides: regenerate affected docs

    return {
        "approval_id": str(approval_id),
        "action":      body.action,
        "status":      "ok",
        "message":     f"Workflow {'resumed' if body.action == 'approve' else 'rejected'}.",
        "audit_id":    str(uuid.uuid4()),
    }


# ── DOCUMENTS ─────────────────────────────────

@app.post("/api/v1/documents/extract")
async def extract_document(
    file: UploadFile = File(...),
    ctx: OrgContext = Depends(get_org_context),
):
    """Upload any trade document → AI extraction pipeline."""
    file_bytes = await file.read()
    result     = await DocumentIntelligenceEngine.extract_from_file(file_bytes, file.content_type)
    return result


@app.post("/api/v1/documents/generate")
async def generate_document(
    body: DocumentGenerationRequest,
    ctx: OrgContext = Depends(get_org_context),
):
    agent   = DocumentGenerationAgent(ctx.org_id)
    results = {}
    for doc_type in body.doc_types:
        result = await agent.run({
            "doc_type":  doc_type,
            "order":     {"id": str(body.order_id)},
            "overrides": body.overrides,
        })
        results[doc_type] = result
    return {"documents": results}


# ── HS CODE ───────────────────────────────────

@app.post("/api/v1/compliance/hs-validate")
async def validate_hs(
    items: list[dict],
    from_country: str = "IN",
    to_country: str = "AE",
    ctx: OrgContext = Depends(get_org_context),
):
    agent  = HSCodeValidationAgent(ctx.org_id)
    result = await agent.run({"items": items, "from_country": from_country, "to_country": to_country})
    return result


# ── AGENT MEMORY ──────────────────────────────

@app.post("/api/v1/memory")
async def upsert_memory(body: MemoryUpsertRequest, ctx: OrgContext = Depends(get_org_context)):
    return {"status": "stored", "key": body.key}


@app.get("/api/v1/memory/search")
async def search_memory(query: str, top_k: int = 5, ctx: OrgContext = Depends(get_org_context)):
    # In production: vector similarity search on agent_memory table
    return {"memories": [], "query": query}


# ── REAL-TIME: WebSocket for live workflow status ──

@app.websocket("/ws/workflow/{workflow_id}")
async def workflow_status_ws(websocket: WebSocket, workflow_id: str):
    await websocket.accept()
    try:
        # Subscribe to Kafka topic for this workflow_id
        # Stream step updates in real-time to the frontend
        for i in range(10):
            await asyncio.sleep(1)
            await websocket.send_json({
                "workflow_id": workflow_id,
                "step":        f"step_{i}",
                "status":      "running",
                "ts":          datetime.utcnow().isoformat(),
            })
    except WebSocketDisconnect:
        pass


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True, workers=1)

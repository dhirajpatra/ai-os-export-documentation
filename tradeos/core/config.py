"""
TradeOS — Central Configuration & LLM Router (core/config.py)
============================================================
Isolated configuration container to break monolithic circular import dependencies.
"""

from __future__ import annotations

import os
import json
import uuid
import httpx
from typing import Any
from pydantic import BaseModel
from dotenv import load_dotenv

load_dotenv()

# ─────────────────────────────────────────────
# BASELINE RUNTIME CONFIGURATION
# ─────────────────────────────────────────────

class Settings:
    APP_NAME = "TradeOS API"
    VERSION  = "0.1.0"

    DATABASE_URL = os.getenv(
        "DATABASE_URL",
        f"postgresql+asyncpg://{os.getenv('POSTGRES_USER','tradeos')}:{os.getenv('POSTGRES_PASSWORD','tradeos')}@{os.getenv('POSTGRES_HOST','localhost')}:{os.getenv('POSTGRES_PORT','5432')}/{os.getenv('POSTGRES_DB','tradeos')}",
    )

    OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://ollama:11434")
    OLLAMA_MODEL    = os.getenv("OLLAMA_MODEL", "qwen2.5:3b")

    LLM_CHAIN = [
        {"provider": "groq",      "model": os.getenv("GROQ_MODEL","llama-3.3-70b-versatile"), "priority": 1},
        {"provider": "gemini",    "model": os.getenv("GEMINI_MODEL","gemini-2.5-flash-preview-04-17"), "priority": 2},
        {"provider": "openai",    "model": os.getenv("OPENAI_MODEL","gpt-4o"), "priority": 3},
        {"provider": "anthropic", "model": os.getenv("ANTHROPIC_MODEL","claude-sonnet-4-6"), "priority": 4},
        # Priority 5: local Ollama — runs on customer AI PC in the future local-first architecture.
        # Currently cloud deployment: used only as last resort fallback.
        # WARNING: qwen2.5:3b is a 3B model. PO extraction quality will degrade significantly
        # compared to cloud providers. Acceptable for local-first with a capable local model
        # (e.g. llama3.1:8b or qwen2.5:7b). Set OLLAMA_MODEL in .env accordingly.
        {"provider": "local",     "model": os.getenv("OLLAMA_MODEL", "qwen2.5:3b"), "priority": 5},
    ]

    TEMPORAL_HOST   = os.getenv("TEMPORAL_HOST",   "localhost:7233")
    S3_BUCKET       = os.getenv("S3_BUCKET", "tradeos-documents")

    WHATSAPP_PROVIDER     = os.getenv("WHATSAPP_PROVIDER",     "meta")
    WHATSAPP_API_URL      = os.getenv("WHATSAPP_API_URL",      "https://graph.facebook.com/v18.0")
    WHATSAPP_TOKEN        = os.getenv("WHATSAPP_TOKEN",        "")
    WHATSAPP_PHONE_ID     = os.getenv("WHATSAPP_PHONE_ID",     "")
    WHATSAPP_VERIFY_TOKEN = os.getenv("WHATSAPP_VERIFY_TOKEN", "")
    WHATSAPP_BUSINESS_ID  = os.getenv("WHATSAPP_BUSINESS_ID",  "")
    TWILIO_ACCOUNT_SID    = os.getenv("TWILIO_ACCOUNT_SID",    "")
    TWILIO_AUTH_TOKEN     = os.getenv("TWILIO_AUTH_TOKEN",     "")
    TWILIO_PHONE_NUMBER   = os.getenv("TWILIO_PHONE_NUMBER",   "")

    JWT_SECRET      = os.getenv("JWT_SECRET")
    JWT_EXPIRE_MINS = os.getenv("JWT_EXPIRE_MINS", "480")

    # ── STRICTLY DYNAMIC FROM .ENV — safe defaults prevent startup crash ──
    CONFIDENCE_THRESHOLD_AUTO           = float(os.getenv("CONFIDENCE_THRESHOLD_AUTO",           "70.0"))
    CONFIDENCE_THRESHOLD_HUMAN          = float(os.getenv("CONFIDENCE_THRESHOLD_HUMAN",           "55.0"))
    CONFIDENCE_THRESHOLD_FALLBACK       = float(os.getenv("CONFIDENCE_THRESHOLD_FALLBACK",        "60.0"))
    CONFIDENCE_THRESHOLD_BLOCK          = float(os.getenv("CONFIDENCE_THRESHOLD_BLOCK",           "50.0"))
    CONFIDENCE_PENALTY_MISSING_FIELD    = float(os.getenv("CONFIDENCE_PENALTY_MISSING_FIELD",     "5.0"))
    CONFIDENCE_PENALTY_MISSING_CRITICAL = float(os.getenv("CONFIDENCE_PENALTY_MISSING_CRITICAL",  "15.0"))
    CONFIDENCE_FLOOR_WHATSAPP           = float(os.getenv("CONFIDENCE_FLOOR_WHATSAPP",            "80.0"))
    CONFIDENCE_FLOOR_PARTIAL            = float(os.getenv("CONFIDENCE_FLOOR_PARTIAL",             "70.0"))
    CONFIDENCE_FLOOR_MINIMAL            = float(os.getenv("CONFIDENCE_FLOOR_MINIMAL",             "60.0"))
    CONFIDENCE_HS_EXACT                 = float(os.getenv("CONFIDENCE_HS_EXACT",                  "90.0"))
    CONFIDENCE_HS_CLOSE                 = float(os.getenv("CONFIDENCE_HS_CLOSE",                  "75.0"))
    CONFIDENCE_HS_BLOCK                 = float(os.getenv("CONFIDENCE_HS_BLOCK",                  "50.0"))
    CONFIDENCE_DEFAULT_FALLBACK         = float(os.getenv("CONFIDENCE_DEFAULT_FALLBACK",         "80.0"))
    PROMPT_TEST_PASS_RATE_THRESHOLD     = float(os.getenv("PROMPT_TEST_PASS_RATE_THRESHOLD",      "0.9"))
    APPROVAL_TIMEOUT_HOURS              = float(os.getenv("APPROVAL_TIMEOUT_HOURS",              "4"))
    SHOW_REVIEW_REASONS                 = os.getenv("SHOW_REVIEW_REASONS", "yes").lower().strip() == "yes"


cfg = Settings()
print(
    f"[Config] CONFIDENCE_THRESHOLD_AUTO={cfg.CONFIDENCE_THRESHOLD_AUTO}%  "
    f"CONFIDENCE_THRESHOLD_HUMAN={cfg.CONFIDENCE_THRESHOLD_HUMAN}%"
)


class OrgContext(BaseModel):
    org_id: uuid.UUID
    user_id: uuid.UUID
    role: str


# ─────────────────────────────────────────────
# COMMON DATA UTILITIES
# ─────────────────────────────────────────────

def parse_llm_json(text: str, context: str) -> Any:
    """
    Parse provider output that should be JSON, tolerating markdown fences
    or short explanatory text around the object.
    """
    cleaned = (text or "").strip()
    if not cleaned:
        raise ValueError(f"{context}: LLM returned an empty response")

    if cleaned.startswith("```"):
        cleaned = cleaned.removeprefix("```json").removeprefix("```").strip()
        if cleaned.endswith("```"):
            cleaned = cleaned[:-3].strip()

    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        object_start = cleaned.find("{")
        array_start = cleaned.find("[")
        starts = [idx for idx in (object_start, array_start) if idx != -1]
        if not starts:
            raise ValueError(f"{context}: LLM response was not JSON: {cleaned[:200]}")

        start = min(starts)
        end = max(cleaned.rfind("}"), cleaned.rfind("]"))
        if end <= start:
            raise ValueError(f"{context}: LLM response contained incomplete JSON: {cleaned[:200]}")

        return json.loads(cleaned[start:end + 1])


# ─────────────────────────────────────────────
# PROVIDER-AGNOSTIC LLM ROUTER LAYER
# ─────────────────────────────────────────────

class LLMRouter:
    """
    Tries providers in priority order.
    Falls back automatically on error or low confidence.
    """

    @staticmethod
    async def complete(
        system_prompt: str,
        user_prompt: str,
        output_schema: dict | None = None,
        max_tokens: int = 2000,
        temperature: float = 0.1,
    ) -> dict:
        from core.redis_client import cache_get, cache_set, generate_cache_key

        # 1. Check Redis Cache
        cache_content = f"{system_prompt}|{user_prompt}|{json.dumps(output_schema)}|{max_tokens}|{temperature}"
        cache_key = generate_cache_key("llm", cache_content)
        
        cached_result = await cache_get(cache_key)
        if cached_result:
            print(f"[LLMRouter] ⚡ Cache hit for prompt: {cache_key}")
            return cached_result

        errors = []
        for provider_cfg in sorted(cfg.LLM_CHAIN, key=lambda x: x["priority"]):
            try:
                LLMRouter._ensure_provider_configured(provider_cfg)
                result = await LLMRouter._call_provider(
                    provider_cfg, system_prompt, user_prompt,
                    output_schema, max_tokens, temperature
                )
                result["provider_used"] = provider_cfg["provider"]
                
                # 2. Store in Redis Cache for 5 mins
                await cache_set(cache_key, result, ttl_seconds=300)
                
                return result
            except Exception as e:
                errors.append(f"{provider_cfg['provider']}: {e}")
                continue
        raise RuntimeError(f"All LLM providers failed: {errors}")

    @staticmethod
    def _env(name: str, default: str = "") -> str:
        return os.getenv(name, default).strip().strip("\"'")

    @staticmethod
    def _looks_configured(value: str) -> bool:
        lowered = value.strip().lower()
        return bool(lowered) and lowered not in {"your key", "your_key", "change-me", "changeme"}

    @staticmethod
    def _ensure_provider_configured(provider_cfg: dict) -> None:
        provider = provider_cfg["provider"]
        if provider == "local":
            return
        if provider == "openai" and not LLMRouter._looks_configured(LLMRouter._env("OPENAI_API_KEY")):
            raise ValueError("OPENAI_API_KEY is not configured")
        if provider == "anthropic" and not LLMRouter._looks_configured(LLMRouter._env("ANTHROPIC_API_KEY")):
            raise ValueError("ANTHROPIC_API_KEY is not configured")
        if provider == "gemini" and not LLMRouter._looks_configured(LLMRouter._env("GEMINI_API_KEY")):
            raise ValueError("GEMINI_API_KEY is not configured")
        if provider == "groq":
            groq_key = LLMRouter._env("GROQ_API_KEY") or LLMRouter._env("XAI_API_KEY")
            if not LLMRouter._looks_configured(groq_key):
                raise ValueError("GROQ_API_KEY / XAI_API_KEY is not configured")

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
        elif provider == "groq":
            return await LLMRouter._groq(model, system_prompt, user_prompt, max_tokens, temperature)
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
        async with httpx.AsyncClient(timeout=120) as client:
            resp = await client.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "x-api-key": LLMRouter._env("ANTHROPIC_API_KEY"),
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
        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.post(
                "https://api.openai.com/v1/chat/completions",
                headers={"Authorization": f"Bearer {LLMRouter._env('OPENAI_API_KEY')}"},
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
    async def _groq(model, system, user, max_tokens, temperature) -> dict:
        base_url = (LLMRouter._env("GROQ_BASE_URL") or LLMRouter._env("XAI_BASE_URL") or "https://api.groq.com/openai/v1").rstrip("/")
        groq_key = LLMRouter._env("GROQ_API_KEY") or LLMRouter._env("XAI_API_KEY")
        async with httpx.AsyncClient(timeout=120) as client:
            resp = await client.post(
                f"{base_url}/chat/completions",
                headers={"Authorization": f"Bearer {groq_key}"},
                json={
                    "model": LLMRouter._env("GROQ_MODEL", model),
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
        base_url = LLMRouter._env("XAI_BASE_URL", "https://api.x.ai/v1").rstrip("/")
        async with httpx.AsyncClient(timeout=120) as client:
            resp = await client.post(
                f"{base_url}/chat/completions",
                headers={"Authorization": f"Bearer {LLMRouter._env('XAI_API_KEY')}"},
                json={
                    "model": LLMRouter._env("XAI_MODEL", model),
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
        resolved_model = LLMRouter._env("GEMINI_MODEL") or model
        async with httpx.AsyncClient(timeout=120) as client:
            resp = await client.post(
                f"https://generativelanguage.googleapis.com/v1beta/models/{resolved_model}:generateContent",
                params={"key": LLMRouter._env("GEMINI_API_KEY")},
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
        base_url = LLMRouter._env("OLLAMA_BASE_URL", "http://ollama:11434").rstrip("/")
        resolved_model = LLMRouter._env("OLLAMA_MODEL") or model
        async with httpx.AsyncClient(timeout=180) as client:
            resp = await client.post(
                f"{base_url}/api/chat",
                json={
                    "model": resolved_model,
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

    @staticmethod
    async def classify_intent(text: str) -> str:
        system = (
            "You are a WhatsApp message classifier for an international seafood and "
            "agricultural export company. Classify the message into exactly one category:\n"
            "- purchase_order : buyer wants to place or discuss a new order "
            "(mentions quantities, prices, goods, delivery, payment terms)\n"
            "- query          : asking about shipment status, documents, pricing, "
            "products, certifications, lead times, or trade processes\n"
            "- complaint      : expressing dissatisfaction about quality, delivery, "
            "service, or a past transaction\n"
            "- greeting       : hello, good morning, hi, thanks, casual chat with "
            "no specific trade request\n"
            "- ignore         : spam, test messages, or completely unrelated content\n"
            "Reply with ONLY the category word. No explanation. No punctuation."
        )
        try:
            result = await LLMRouter.complete(
                system_prompt=system,
                user_prompt=text[:500],
                max_tokens=8,
                temperature=0.0,
            )
            raw = result.get("text", "").strip().lower().rstrip(".")
            valid = ("purchase_order", "query", "complaint", "greeting", "ignore")
            if raw in valid:
                return raw
            for v in valid:
                if v in raw:
                    return v
            return "purchase_order"
        except Exception:
            return "purchase_order"


# ─────────────────────────────────────────────
# DOCUMENT INTELLIGENCE ENGINE
# ─────────────────────────────────────────────

class DocumentIntelligenceEngine:
    """
    Orchestrates the full document intelligence pipeline.
    Actual OCR, table detection, and LLM extraction are
    delegated to core.ocr_service.
    """

    @staticmethod
    async def extract_from_file(file_bytes: bytes, mime_type: str) -> dict:
        """
        Full pipeline: OCR → table detection → stamp detection → LLM extraction.
        Returns: {raw_text, tables, stamps, extracted}
        Raises RuntimeError if text extraction fails entirely.
        """
        from core.ocr_service import full_document_pipeline
        return await full_document_pipeline(file_bytes, mime_type)


# ─────────────────────────────────────────────
# HITL ORCHESTRATOR
# ─────────────────────────────────────────────

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

        # SCALE RECONCILIATION LAYER:
        # Standardizes fractional decimal confidence (e.g. 0.95) to percentage scales (95.0)
        # to ensure correct evaluations against your configured .env criteria.
        normalized_confidence = confidence * 100.0 if confidence <= 1.0 else confidence

        if normalized_confidence >= cfg.CONFIDENCE_THRESHOLD_AUTO and not high_flags:
            return {
                "decision": "auto_approve",
                "reason":   f"Confidence {normalized_confidence:.1f}% meets auto-approve threshold ({cfg.CONFIDENCE_THRESHOLD_AUTO}%)",
                "requires_human": False,
            }

        if normalized_confidence < cfg.CONFIDENCE_THRESHOLD_HUMAN or high_flags:
            return {
                "decision": "require_human",
                "reason":   (
                    f"Confidence {normalized_confidence:.1f}% is lower than threshold ({cfg.CONFIDENCE_THRESHOLD_HUMAN}%)"
                    if normalized_confidence < cfg.CONFIDENCE_THRESHOLD_HUMAN
                    else f"High-severity flags: {[f['message'] for f in high_flags]}"
                ),
                "requires_human": True,
            }

        return {
            "decision": "soft_review",
            "reason":   f"Moderate confidence ({normalized_confidence:.1f}%) — routing for standard review checklist.",
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
"""
TradeOS — FastAPI Backend Service
==================================
Async · Multi-tenant · Event-driven
All agents are modular and LLM-provider-agnostic.

Changes from previous version
------------------------------
  1. Redis init/close added to lifespan() — required for SSE streaming.
  2. CORS origins tightened to Railway + Vercel + localhost (was allow_origins=["*"]).
  3. Everything else is identical to the file you uploaded.
"""

from __future__ import annotations

import asyncio
import html
import json
import os
import re
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timedelta
from typing import Any
from dotenv import load_dotenv
load_dotenv()

import httpx
from fastapi import (
    BackgroundTasks, Depends, FastAPI, File, Form, HTTPException,
    Request, UploadFile, WebSocket, WebSocketDisconnect, status,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel, Field

# ── Updated Core Config Imports ──
from core.config import (
    cfg,
    LLMRouter,
    parse_llm_json,
    OrgContext,
    DocumentIntelligenceEngine,
    HITLOrchestrator
)

# ── Import Distributed Subsystems ──
from services.agents.po_extraction import POExtractionAgent
from services.agents.hs_validation import HSCodeValidationAgent
from services.agents.doc_generation import DocumentGenerationAgent
from services.integrations.whatsapp import WhatsAppService
from services.workflows.po_workflow import KillerDemoWorkflow


# ─────────────────────────────────────────────
# DOCUMENT INTELLIGENCE ENGINE
# ─────────────────────────────────────────────

class DocumentIntelligenceEngine:
    """
    Orchestrates the full document intelligence pipeline.
    Actual OCR, table detection, and LLM extraction are
    delegated to core.ocr_service — import from there directly
    when you need individual stages.
    """

    @staticmethod
    async def extract_from_file(file_bytes: bytes, mime_type: str) -> dict:
        from core.ocr_service import full_document_pipeline
        return await full_document_pipeline(file_bytes, mime_type)


# ─────────────────────────────────────────────
# HITL ORCHESTRATOR
# ─────────────────────────────────────────────

class HITLOrchestrator:
    """Human-In-The-Loop decision engine. Determines: auto-approve | flag for human | block."""

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

        normalized_confidence = confidence * 100.0 if confidence <= 1.0 else confidence

        if normalized_confidence >= cfg.CONFIDENCE_THRESHOLD_AUTO and not high_flags:
            return {
                "decision": "auto_approve",
                "reason":   f"Confidence {normalized_confidence:.1f}% above threshold ({cfg.CONFIDENCE_THRESHOLD_AUTO}%), no high-severity flags",
                "requires_human": False,
            }

        if normalized_confidence < cfg.CONFIDENCE_THRESHOLD_HUMAN or high_flags:
            return {
                "decision": "require_human",
                "reason":   (
                    f"Confidence {normalized_confidence:.1f}% below threshold ({cfg.CONFIDENCE_THRESHOLD_HUMAN}%)"
                    if normalized_confidence < cfg.CONFIDENCE_THRESHOLD_HUMAN
                    else f"High-severity flags: {[f['message'] for f in high_flags]}"
                ),
                "requires_human": True,
            }

        return {
            "decision": "soft_review",
            "reason":   f"Moderate confidence ({normalized_confidence:.1f}%) — flagging for optional review",
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
# README RENDER GENERATOR
# ─────────────────────────────────────────────

def render_readme_html() -> str:
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(cfg.APP_NAME)} README</title>
  <style>
    :root {{
      color-scheme: light;
      --bg: #f6f8fb;
      --panel: #ffffff;
      --text: #17202a;
      --muted: #5f6b7a;
      --line: #d9e0ea;
      --accent: #1266d6;
      --code: #101828;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      background: var(--bg);
      color: var(--text);
      font: 16px/1.62 Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }}
    main {{
      max-width: 980px;
      margin: 0 auto;
      padding: 42px 22px 64px;
    }}
    article {{
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: clamp(24px, 5vw, 52px);
      box-shadow: 0 18px 50px rgba(23, 32, 42, 0.08);
    }}
    h1, h2, h3, h4 {{ line-height: 1.18; margin: 1.45em 0 0.55em; }}
    h1 {{ margin-top: 0; font-size: clamp(2.2rem, 7vw, 4.2rem); color: #111827; }}
    h2 {{ border-top: 1px solid var(--line); padding-top: 1.2em; font-size: 1.75rem; }}
    h3 {{ font-size: 1.24rem; color: #263445; }}
    p {{ margin: 0.8em 0; }}
    a {{ color: var(--accent); text-decoration-thickness: 0.08em; text-underline-offset: 0.18em; }}
    blockquote {{
      margin: 1.2em 0;
      padding: 0.2em 0 0.2em 1.1em;
      border-left: 4px solid var(--accent);
      color: var(--muted);
      font-size: 1.08rem;
    }}
    hr {{ border: 0; border-top: 1px solid var(--line); margin: 2rem 0; }}
    pre {{
      overflow-x: auto;
      padding: 16px 18px;
      border-radius: 8px;
      background: var(--code);
      color: #f8fafc;
      line-height: 1.45;
    }}
    code {{
      font-family: "SFMono-Regular", Consolas, "Liberation Mono", monospace;
      font-size: 0.92em;
    }}
    :not(pre) > code {{
      background: #eef3f8;
      color: #243042;
      padding: 0.16em 0.38em;
      border-radius: 5px;
    }}
    ul, ol {{ padding-left: 1.35rem; }}
    table {{
      width: 100%;
      border-collapse: collapse;
      margin: 1.2em 0;
      display: block;
      overflow-x: auto;
    }}
    th, td {{
      border: 1px solid var(--line);
      padding: 10px 12px;
      vertical-align: top;
      min-width: 140px;
    }}
    th {{ background: #eef3f8; text-align: left; }}
  </style>
</head>
<body>
  <main>
    <article>
      <h1>TradeOS</h1>
      <h2>Agentic AI Operating System for Export Documentation</h2>
      <p>"AI operates workflows. Humans supervise."</p>
      <p>TradeOS replaces manual export documentation, WhatsApp-based operations, and fragmented systems
      with an autonomous multi-agent AI layer for India–GCC trade corridors.</p>
    </article>
  </main>
</body>
</html>"""


# ─────────────────────────────────────────────
# FASTAPI LIFECYCLE MANAGEMENT
# ─────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    # ── Startup ────────────────────────────────────────────
    print("🚀 TradeOS API starting — connecting to Redis, DB, Kafka, Temporal…")

    # ① Redis — init first so SSE bus is ready before any request lands.
    #    Uses REDIS_URL from .env (Upstash rediss:// URL).
    #    Non-fatal: REST APIs keep working even if Redis is down.
    try:
        from core.redis_client import init_redis
        await init_redis()
        print("✅ Redis (Upstash) connected — SSE streaming enabled")
    except Exception as exc:
        print(f"⚠️  Redis connection failed: {exc}")
        print("   SSE streaming will be unavailable. Check REDIS_URL in Railway env vars.")

    # ② pypdf availability check (unchanged)
    try:
        from pypdf import PdfReader
        print("✅ pypdf available — text-layer PDF extraction enabled")
    except ImportError:
        print("⚠️  pypdf NOT installed. PDF text extraction will fall back to PaddleOCR.")
        print("   Fix: add 'pypdf' to requirements.txt and rebuild the image.")

    # ③ DB pool (unchanged)
    try:
        from core.db import init_pool, SEED_ORG_ID, get_pool
        await init_pool()
    except Exception as exc:
        print(f"⚠️  DB pool failed to initialise: {exc}")
        print("   Approval/shipment persistence will be unavailable this session.")

    # ④ Knowledge base seed (unchanged)
    try:
        from core.db import get_pool, SEED_ORG_ID
        from core.knowledge_base import KnowledgeBase
        pool = get_pool()
        await KnowledgeBase.seed(pool, SEED_ORG_ID)
    except Exception as exc:
        print(f"⚠️  Knowledge base seed failed: {exc}")
        print("   FAQ/RAG answers will fall back to hardcoded replies.")

    # ⑤ Kafka (unchanged — disabled)
    print("ℹ️  Kafka integration is disabled")

    yield

    # ── Shutdown ───────────────────────────────────────────
    # Close Redis first (flush any pending pub/sub)
    try:
        from core.redis_client import close_redis
        await close_redis()
        print("✅ Redis connection closed")
    except Exception:
        pass

    try:
        from core.db import close_pool
        await close_pool()
    except Exception:
        pass

    print("🛑 TradeOS API shutting down…")


# ─────────────────────────────────────────────
# APP INSTANCE
# ─────────────────────────────────────────────

app = FastAPI(
    title=cfg.APP_NAME,
    version=cfg.VERSION,
    description="Agentic AI OS for Export Documentation — Async · Multi-tenant · Event-driven",
    lifespan=lifespan,
)

# CORS — explicitly list allowed origins.
# "allow_origins=['*']" blocks EventSource in some browsers when
# credentials are involved. Listing origins explicitly is safer.
_VERCEL_URL   = os.getenv("VERCEL_URL", "")       # auto-set by Vercel on preview deploys
_RAILWAY_DOMAIN = os.getenv("RAILWAY_DOMAIN", "") # set in your Railway env vars

_ALLOWED_ORIGINS = [
    # ── Production ──────────────────────────────────────────────────
    "https://ai-os-export-documentation.vercel.app",   # your Vercel prod domain
    _RAILWAY_DOMAIN,                                    # self (for API docs UI)
    # ── Preview / branch deploys ────────────────────────────────────
    f"https://{_VERCEL_URL}" if _VERCEL_URL else "",
    # ── Local dev ───────────────────────────────────────────────────
    "http://localhost:3000",   # CRA
    "http://localhost:5173",   # Vite
    "http://localhost:4173",   # Vite preview
    "http://localhost:8000",   # FastAPI docs UI
]

# Filter out empty strings from missing env vars
_ALLOWED_ORIGINS = [o for o in _ALLOWED_ORIGINS if o]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_ALLOWED_ORIGINS,
    allow_origin_regex=r"https://.*\.vercel\.app",  # all Vercel preview URLs
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Content-Type", "Cache-Control", "X-Accel-Buffering"],
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
# ROUTING
# ─────────────────────────────────────────────

from services.api.routes import router as api_router
app.include_router(api_router)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=int(os.getenv("PORT", 8000)),  # Railway injects PORT automatically
        reload=True,
        workers=1,
    )

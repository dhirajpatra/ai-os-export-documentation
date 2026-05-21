"""
TradeOS — FastAPI Backend Service
==================================
Async · Multi-tenant · Event-driven
All agents are modular and LLM-provider-agnostic.
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
# Thin orchestration layer — all OCR logic lives
# in services/ocr_service.py for clean separation.
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
# PYDANTIC INBOUND SCHEMAS
# ─────────────────────────────────────────────

class POIngestRequest(BaseModel):
    """Ingest a purchase order from any source."""
    source: str = Field(..., description="whatsapp | email | portal | manual")
    raw_text: str | None = None
    buyer_contact_id: uuid.UUID | None = None
    metadata: dict = Field(default_factory=dict)


class ExtractionResult(BaseModel):
    buyer_name: str | None
    buyer_country: str | None
    items: list[dict]
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
    doc_types: list[str]
    overrides: dict = Field(default_factory=dict)


class ApprovalAction(BaseModel):
    action: str = Field(..., pattern="^(approve|reject|request_changes)$")
    note: str | None = None
    field_overrides: dict = Field(default_factory=dict)


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
      <p>TradeOS replaces manual export documentation, WhatsApp-based operations, and fragmented systems with an autonomous multi-agent AI layer for India–GCC trade corridors. AI agents and employees collaborate from the same projects, conversations, and files, governed centrally and connected to existing enterprise systems.</p>
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
    print("🚀 TradeOS API starting — connecting to DB, Kafka, Temporal…")

    try:
        from pypdf import PdfReader
        print("✅ pypdf available — text-layer PDF extraction enabled")
    except ImportError:
        print("⚠️  pypdf NOT installed. PDF text extraction will fall back to PaddleOCR.")
        print("   Fix: add 'pypdf' to requirements.txt and rebuild the image.")

    try:
        from core.db import init_pool, SEED_ORG_ID, get_pool
        await init_pool()
    except Exception as exc:
        print(f"⚠️  DB pool failed to initialise: {exc}")
        print("   Approval/shipment persistence will be unavailable this session.")

    # Knowledge base — seed FAQ into agent_memory (idempotent)
    try:
        from core.db import get_pool, SEED_ORG_ID
        from core.knowledge_base import KnowledgeBase
        pool = get_pool()
        await KnowledgeBase.seed(pool, SEED_ORG_ID)
    except Exception as exc:
        print(f"⚠️  Knowledge base seed failed: {exc}")
        print("   FAQ/RAG answers will fall back to hardcoded replies.")

    yield

    # ── Shutdown ───────────────────────────────────────────
    try:
        from core.db import close_pool
        await close_pool()
    except Exception:
        pass
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
# ROUTING HANDLERS
# ─────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "ok", "version": cfg.VERSION, "service": cfg.APP_NAME}


@app.get("/", response_class=HTMLResponse)
async def readme_home():
    """Render README.md as a formatted HTML page."""
    return HTMLResponse(render_readme_html())


# ── KILLER DEMO: Full workflow ────────────────

@app.post("/api/v1/workflow/po-to-dispatch")
async def run_killer_demo(
    background_tasks: BackgroundTasks,
    po_text: str | None = Form(None),
    buyer_whatsapp: str | None = Form(None),
    buyer_email: str | None = Form(None),
    file: UploadFile | None = File(None),
    ctx: OrgContext = Depends(get_org_context),
):
    """
    THE KILLER DEMO ENDPOINT.
    Feed it a PO (text or PDF) and it runs the full pipeline:
    Extract → HS Validate → Generate Invoice + Packing List
    → HITL decision → Send WhatsApp/Email → Return full result.
    """
    from core.workflow_engine import build_po_to_dispatch_workflow

    file_bytes = await file.read() if file else None
    if not file_bytes and not (po_text or "").strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Send either po_text as a form field or upload a file.",
        )

    raw_input = {
        "raw_text":       po_text or "",
        "buyer_whatsapp": buyer_whatsapp,
        "buyer_email":    buyer_email,
    }
    if file_bytes:
        raw_input["file_bytes"] = file_bytes
        raw_input["mime_type"]  = file.content_type if file else "application/pdf"

    source = "file" if file_bytes else "whatsapp" if buyer_whatsapp else "portal"

    engine, wf_ctx = build_po_to_dispatch_workflow(
        org_id=str(ctx.org_id),
        source=source,
        raw_input=raw_input,
    )

    async def ws_hook(event: dict):
        pass

    engine.on_event(ws_hook)

    try:
        result = await engine.run()
    except (RuntimeError, ValueError) as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(exc),
        ) from exc
    return result


# ── WHATSAPP WEBHOOK INTERFACES ───────────────

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
        background_tasks.add_task(
            _process_inbound_whatsapp,
            msg,
            org_id=uuid.UUID("00000000-0000-0000-0000-000000000001"),
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
            org_id=uuid.UUID("00000000-0000-0000-0000-000000000001"),
        )
    return {"status": "received"}


async def _process_inbound_whatsapp(msg: dict, org_id: uuid.UUID):
    """
    Background task: process inbound WhatsApp message → run deterministic workflow.
    Handles two message types:
      - text:     PO sent as plain WhatsApp text
      - document: PO sent as a PDF attachment (downloaded from Meta)
    """
    msg_type = msg.get("type")
    text     = msg.get("text", "")
    sender   = msg.get("from")
    file_bytes: bytes | None = None
    mime_type  = "application/pdf"

    # ── Route by message type ──────────────────────────────
    if msg_type == "document":
        media_id = msg.get("media_id")
        if not media_id:
            media_urls = msg.get("media_urls", [])
            if media_urls:
                async with httpx.AsyncClient(timeout=60) as client:
                    resp = await client.get(media_urls[0])
                    resp.raise_for_status()
                    file_bytes = resp.content
            else:
                return
        else:
            await WhatsAppService.send_text(
                to=sender,
                body="📄 PDF received! Processing your purchase order...",
            )
            file_bytes = await WhatsAppService.download_media(media_id)
        mime_type = msg.get("mime_type", "application/pdf")

    elif msg_type == "text":
        if not text.strip():
            return

        # ── Intent gate — classify before touching the workflow ────────
        intent = await LLMRouter.classify_intent(text)
        print(f"[WA intent] intent={intent} from={sender}")

        if intent == "ignore":
            return

        if intent in ("query", "greeting", "complaint"):
            try:
                from core.db import get_pool
                from core.knowledge_base import KnowledgeBase
                pool  = get_pool()
                reply = await KnowledgeBase.answer(
                    pool=pool,
                    org_id=str(org_id),
                    question=text,
                    intent=intent,
                )
            except Exception as exc:
                print(f"[WA intent] KnowledgeBase.answer failed: {exc}")
                if intent == "complaint":
                    reply = (
                        "We sincerely apologize for the inconvenience. "
                        "Our team will contact you within 24 hours. Thank you for your patience."
                    )
                elif intent == "greeting":
                    reply = (
                        "Hello! 👋 Welcome to Agro Exports India. "
                        "How can I assist you with your export requirements today?"
                    )
                else:
                    reply = (
                        "Thank you for your question. "
                        "Our team will get back to you shortly with the information you need."
                    )
            if sender:
                await WhatsAppService.send_text(to=sender, body=reply)
            return

    else:
        return

    # ── Build and run workflow ────────
    raw_input = {
        "raw_text":       text,
        "buyer_whatsapp": sender,
    }
    if file_bytes:
        raw_input["file_bytes"] = file_bytes
        raw_input["mime_type"]  = mime_type

    source = "file" if file_bytes else "whatsapp"

    result: dict = {}
    try:
        # ── Primary: deterministic WorkflowEngine (saga pattern) ──
        from core.workflow_engine import build_po_to_dispatch_workflow
        engine, _ = build_po_to_dispatch_workflow(
            org_id=str(org_id),
            source=source,
            raw_input=raw_input,
        )
        result = await engine.run()

        if result.get("status") == "failed":
            step_statuses = result.get("step_statuses", {})
            print(f"[WA workflow] WorkflowEngine step failure: {step_statuses}")
            raise RuntimeError(f"WorkflowEngine returned failed. Steps: {step_statuses}")

    except Exception as primary_exc:
        import traceback
        print(f"[WA workflow] WorkflowEngine failed — {primary_exc}")
        traceback.print_exc()

        # ── Fallback: Distributed KillerDemoWorkflow Runner ──
        try:
            wf = KillerDemoWorkflow(org_id=org_id)
            result = await wf.execute(
                source=source,
                raw_text=text or None,
                file_bytes=file_bytes,
                buyer_whatsapp=sender,
            )
            if result.get("status") == "awaiting_approval":
                result["status"] = "awaiting_human"

        except Exception as fallback_exc:
            print(f"[WA workflow] KillerDemoWorkflow fallback also failed — {fallback_exc}")
            traceback.print_exc()
            if sender:
                try:
                    await WhatsAppService.send_text(
                        to=sender,
                        body=(
                            "⚠️ We received your document but hit a temporary issue "
                            "processing it. Our team has been notified and will follow up shortly."
                        ),
                    )
                except Exception:
                    pass
            return

    confidence = float(
        result.get("overall_confidence")
        or result.get("confidence")
        or 0.0
    )
    result["overall_confidence"] = confidence

    print(f"[WA workflow] status={result.get('status')} confidence={confidence}")

    if sender and result.get("status") in ("awaiting_human", "awaiting_approval"):
        approval_id = result.get("approval_id", "N/A")
        await WhatsAppService.send_text(
            to=sender,
            body=(
                f"✅ *PO Received & Processed!*\n\n"
                f"🎯 Confidence: {confidence:.0f}%\n"
                f"📋 Status: Under Review\n\n"
                f"⏳ Our team is reviewing your order. "
                f"You'll receive the documents shortly.\n"
                f"Reference ID: `{approval_id}`"
            ),
        )


# ── HUMAN IN THE LOOP (HITL) APPROVALS ────────

@app.get("/api/v1/approvals")
async def list_approvals(
    status_filter: str = "pending",
    ctx: OrgContext = Depends(get_org_context),
):
    """Fetch approval requests for this org, filtered by status (default: pending)."""
    try:
        from core.db import get_pool
        pool = get_pool()
        async with pool.acquire() as db:
            rows = await db.fetch(
                """
                SELECT
                    id, workflow_id, order_id, requested_by,
                    title, description, ai_confidence, risk_flags,
                    suggested_action, diff_after,
                    status, assigned_to, expires_at, created_at
                FROM approval_requests
                WHERE org_id = $1
                  AND status = $2
                ORDER BY created_at DESC
                LIMIT 100
                """,
                ctx.org_id,
                status_filter,
            )
            approvals = [dict(r) for r in rows]
            for a in approvals:
                for k, v in a.items():
                    if hasattr(v, "isoformat"):
                        a[k] = v.isoformat()
                    elif hasattr(v, "__str__") and not isinstance(v, (str, int, float, bool, type(None))):
                        a[k] = str(v)
        return {"approvals": approvals, "total": len(approvals)}
    except RuntimeError:
        return {"approvals": [], "total": 0, "warning": "DB unavailable"}


@app.post("/api/v1/approvals/{approval_id}/action")
async def action_approval(
    approval_id: uuid.UUID,
    body: ApprovalAction,
    ctx: OrgContext = Depends(get_org_context),
):
    """
    Human approves / rejects / requests changes on a paused workflow.
    """
    from core.db import get_pool
    from core.workflow_engine import get_engine

    pool = get_pool()
    async with pool.acquire() as db:

        row = await db.fetchrow(
            """
            SELECT id, workflow_id, order_id, status, org_id
            FROM approval_requests
            WHERE id = $1 AND org_id = $2
            """,
            approval_id,
            ctx.org_id,
        )
        if not row:
            raise HTTPException(status_code=404, detail="Approval request not found")
        if row["status"] != "pending":
            raise HTTPException(
                status_code=409,
                detail=f"Approval is already '{row['status']}' — cannot act again",
            )

        new_status = {
            "approve":          "approved",
            "reject":           "rejected",
            "request_changes":  "pending",
        }[body.action]

        audit_id = uuid.uuid4()
        await db.execute(
            """
            INSERT INTO audit_log (
                org_id, actor_type, actor_id, action,
                entity_type, entity_id,
                old_value, new_value, metadata
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            """,
            ctx.org_id,
            "user",
            str(ctx.user_id),
            f"approval.{body.action}",
            "approval_request",
            str(approval_id),
            json.dumps({"status": "pending"}),
            json.dumps({"status": new_status, "note": body.note}),
            json.dumps({"field_overrides": body.field_overrides}),
        )

        await db.execute(
            """
            UPDATE approval_requests
            SET status      = $1,
                reviewed_by = $2,
                reviewed_at = NOW(),
                review_note = $3,
                diff_after  = COALESCE($4::jsonb, diff_after)
            WHERE id = $5
            """,
            new_status,
            ctx.user_id,
            body.note,
            json.dumps(body.field_overrides) if body.field_overrides else None,
            approval_id,
        )

        workflow_id = str(row["workflow_id"])
        engine = get_engine(workflow_id)

        resumed_result: dict | None = None
        if engine:
            try:
                resumed_result = await engine.resume_from_approval(
                    approval_action=body.action,
                    overrides=body.field_overrides or None,
                )
                print(f"[Approval] workflow {workflow_id} resumed → {resumed_result.get('status')}")
            except Exception as exc:
                print(f"[Approval] resume failed for workflow {workflow_id}: {exc}")
        else:
            print(f"[Approval] no live engine for workflow {workflow_id} — persisted only")

    return {
        "approval_id":    str(approval_id),
        "action":         body.action,
        "new_status":     new_status,
        "workflow_id":    workflow_id,
        "resumed_status": resumed_result.get("status") if resumed_result else "engine_not_found",
        "audit_id":       str(audit_id),
        "message":        f"Approval {body.action}d and workflow updated.",
    }


# ── DOCUMENTS PROCESSING & PRODUCTION ──────────

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


# ── COMPLIANCE HS CODE EVALUATION ─────────────

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


# ── AGENT MEMORY ROUTING ──────────────────────

@app.post("/api/v1/memory")
async def upsert_memory(body: MemoryUpsertRequest, ctx: OrgContext = Depends(get_org_context)):
    return {"status": "stored", "key": body.key}


@app.get("/api/v1/memory/search")
async def search_memory(query: str, top_k: int = 5, ctx: OrgContext = Depends(get_org_context)):
    return {"memories": [], "query": query}


# ── REAL-TIME MONITORING WORKSPACES ───────────

@app.websocket("/ws/workflow/{workflow_id}")
async def workflow_status_ws(websocket: WebSocket, workflow_id: str):
    await websocket.accept()
    try:
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
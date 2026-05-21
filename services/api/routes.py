import os
import json
import uuid
import httpx
import asyncio
from datetime import datetime
from typing import Any

from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, HTTPException, Request, UploadFile, WebSocket, WebSocketDisconnect, status
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field

from core.config import cfg, LLMRouter, OrgContext
from services.agents.hs_validation import HSCodeValidationAgent
from services.agents.doc_generation import DocumentGenerationAgent
from services.integrations.whatsapp import WhatsAppService
from services.workflows.po_workflow import KillerDemoWorkflow
from services.api.main import DocumentIntelligenceEngine, HITLOrchestrator, render_readme_html, get_org_context

router = APIRouter()

# ─────────────────────────────────────────────
# PYDANTIC INBOUND SCHEMAS
# ─────────────────────────────────────────────

class POIngestRequest(BaseModel):
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
# ROUTING HANDLERS
# ─────────────────────────────────────────────

@router.get("/health")
async def health():
    return {"status": "ok", "version": cfg.VERSION, "service": cfg.APP_NAME}


@router.get("/", response_class=HTMLResponse)
async def readme_home():
    """Render README.md as a formatted HTML page."""
    return HTMLResponse(render_readme_html())


# ── KILLER DEMO: Full workflow ────────────────

@router.post("/api/v1/workflow/po-to-dispatch")
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

@router.get("/api/v1/webhooks/whatsapp")
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


@router.post("/api/v1/webhooks/whatsapp")
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


@router.post("/api/v1/webhooks/twilio/whatsapp")
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
        
        # Build review reasons from risk flags
        risk_flags = result.get("risk_flags", [])
        reason_msg = ""
        if risk_flags:
            flags_text = "\n".join([f"⚠️ {f.get('message', '')}" for f in risk_flags])
            reason_msg = f"\n*Review Required For:*\n{flags_text}\n"
        
        await WhatsAppService.send_text(
            to=sender,
            body=(
                f"✅ *PO Received & Processed!*\n\n"
                f"🎯 Confidence: {confidence:.0f}%\n"
                f"📋 Status: Under Review\n"
                f"{reason_msg}\n"
                f"⏳ Our team is reviewing your order. "
                f"You'll receive the documents shortly.\n"
                f"Reference ID: `{approval_id}`"
            ),
        )


# ── HUMAN IN THE LOOP (HITL) APPROVALS ────────

@router.get("/api/v1/approvals")
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


@router.post("/api/v1/approvals/{approval_id}/action")
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

@router.post("/api/v1/documents/extract")
async def extract_document(
    file: UploadFile = File(...),
    ctx: OrgContext = Depends(get_org_context),
):
    """Upload any trade document → AI extraction pipeline."""
    file_bytes = await file.read()
    result     = await DocumentIntelligenceEngine.extract_from_file(file_bytes, file.content_type)
    return result


@router.post("/api/v1/documents/generate")
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

@router.post("/api/v1/compliance/hs-validate")
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

@router.post("/api/v1/memory")
async def upsert_memory(body: MemoryUpsertRequest, ctx: OrgContext = Depends(get_org_context)):
    return {"status": "stored", "key": body.key}


@router.get("/api/v1/memory/search")
async def search_memory(query: str, top_k: int = 5, ctx: OrgContext = Depends(get_org_context)):
    return {"memories": [], "query": query}


# ── REAL-TIME MONITORING WORKSPACES ───────────

@router.websocket("/ws/workflow/{workflow_id}")
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

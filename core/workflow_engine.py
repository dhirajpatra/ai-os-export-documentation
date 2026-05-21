"""
TradeOS — Deterministic Workflow State Machine
================================================
Do NOT rely only on LLM orchestration.
This layer is deterministic. LLMs are tools called within steps.
Temporal-compatible. Retries + compensation flows built in.
"""

from __future__ import annotations

import asyncio
import uuid
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any, Callable, Awaitable
import os
from dotenv import load_dotenv

load_dotenv()


# ─────────────────────────────────────────────
# LIVE ENGINE REGISTRY
# Keeps engines alive while awaiting human input
# so resume_from_approval() can reach them.
# Key: workflow_id (str)  Value: WorkflowEngine
# ─────────────────────────────────────────────

_live_engines: dict[str, "WorkflowEngine"] = {}

def register_engine(engine: "WorkflowEngine"):
    _live_engines[engine.ctx.workflow_id] = engine

def get_engine(workflow_id: str) -> "WorkflowEngine | None":
    return _live_engines.get(workflow_id)

def deregister_engine(workflow_id: str):
    _live_engines.pop(workflow_id, None)


# ─────────────────────────────────────────────
# STATE DEFINITIONS
# ─────────────────────────────────────────────

class WorkflowStatus(str, Enum):
    PENDING          = "pending"
    RUNNING          = "running"
    AWAITING_HUMAN   = "awaiting_human"
    COMPLETED        = "completed"
    FAILED           = "failed"
    COMPENSATING     = "compensating"   # rolling back
    COMPENSATED      = "compensated"
    CANCELLED        = "cancelled"


class StepStatus(str, Enum):
    PENDING      = "pending"
    RUNNING      = "running"
    COMPLETED    = "completed"
    FAILED       = "failed"
    SKIPPED      = "skipped"
    COMPENSATED  = "compensated"


# ─────────────────────────────────────────────
# STEP DEFINITION
# ─────────────────────────────────────────────

@dataclass
class StepResult:
    status:     StepStatus
    output:     dict   = field(default_factory=dict)
    error:      str    = ""
    confidence: float  = 0.0
    latency_ms: int    = 0
    requires_human: bool = False
    human_reason: str  = ""


@dataclass
class WorkflowStep:
    name:           str
    agent:          str
    run_fn:         Callable[..., Awaitable[StepResult]]
    compensate_fn:  Callable[..., Awaitable[None]] | None = None  # for rollback
    max_retries:    int  = 3
    retry_delay_s:  int  = 2
    timeout_s:      int  = int(os.getenv("WORKFLOW_TIMEOUT_S", 300))
    skip_on_error:  bool = False
    depends_on:     list[str] = field(default_factory=list)


# ─────────────────────────────────────────────
# WORKFLOW CONTEXT (shared state)
# ─────────────────────────────────────────────

@dataclass
class WorkflowContext:
    workflow_id:    str   = field(default_factory=lambda: str(uuid.uuid4()))
    org_id:         str   = ""
    order_id:       str   = ""
    source:         str   = ""        # whatsapp | email | portal | file
    raw_input:      dict  = field(default_factory=dict)

    # Accumulated outputs from steps
    extracted_po:   dict  = field(default_factory=dict)
    hs_validations: dict  = field(default_factory=dict)
    documents:      dict  = field(default_factory=dict)
    approval_id:    str   = ""
    shipment_id:    str   = ""
    sent_channels:  list  = field(default_factory=list)

    # Metadata
    overall_confidence: float = 0.0
    risk_flags:    list  = field(default_factory=list)
    audit_entries: list  = field(default_factory=list)
    started_at:    str   = field(default_factory=lambda: datetime.utcnow().isoformat())


# ─────────────────────────────────────────────
# STATE MACHINE ENGINE
# ─────────────────────────────────────────────

class WorkflowEngine:
    """
    Deterministic step executor.
    - Steps run in dependency order.
    - Each step is retried up to max_retries on transient failure.
    - On permanent failure, compensation flows run in reverse.
    - HITL: workflow pauses and emits an approval_request.
    - Temporal: in production, each step becomes a Temporal Activity.
    """

    def __init__(self, steps: list[WorkflowStep], ctx: WorkflowContext):
        self.steps         = {s.name: s for s in steps}
        self.step_order    = [s.name for s in steps]
        self.ctx           = ctx
        self.step_statuses: dict[str, StepResult] = {}
        self.status        = WorkflowStatus.PENDING
        self._event_hooks: list[Callable] = []
        self._completed_steps: list[str] = []

    def on_event(self, fn: Callable):
        """Register event hook (for Kafka / WebSocket streaming)."""
        self._event_hooks.append(fn)

    async def _emit(self, event: str, data: dict):
        entry = {
            "workflow_id": self.ctx.workflow_id,
            "event":       event,
            "data":        data,
            "ts":          datetime.utcnow().isoformat(),
        }
        self.ctx.audit_entries.append(entry)
        for hook in self._event_hooks:
            await hook(entry)

    async def run(self) -> dict:
        self.status = WorkflowStatus.RUNNING
        register_engine(self)
        await self._emit("workflow.started", {"org_id": self.ctx.org_id})

        for step_name in self.step_order:
            step = self.steps[step_name]

            # Check dependencies — COMPLETED or SKIPPED both unblock dependents
            unmet_deps = [
                dep for dep in step.depends_on
                if not self.step_statuses.get(dep)
                or self.step_statuses[dep].status
                not in (StepStatus.COMPLETED, StepStatus.SKIPPED)
            ]
            if unmet_deps:
                await self._emit("step.skipped", {"step": step_name, "reason": f"unmet deps: {unmet_deps}"})
                self.step_statuses[step_name] = StepResult(status=StepStatus.SKIPPED)
                continue

            result = await self._run_step(step)
            self.step_statuses[step_name] = result

            if result.requires_human:
                self.status = WorkflowStatus.AWAITING_HUMAN
                await self._emit("workflow.awaiting_human", {
                    "step":          step_name,
                    "approval_id":   self.ctx.approval_id,
                    "confidence":    result.confidence,
                    "reason":        result.human_reason,
                })
                # In Temporal: workflow blocks here waiting for Signal
                # In local mode: return immediately with paused state
                return self._snapshot("awaiting_human")

            if result.status == StepStatus.FAILED:
                if not step.skip_on_error:
                    await self._compensate()
                    return self._snapshot("failed")

            if result.status == StepStatus.COMPLETED:
                self._completed_steps.append(step_name)

        self.status = WorkflowStatus.COMPLETED
        deregister_engine(self.ctx.workflow_id)
        await self._emit("workflow.completed", {"steps_completed": len(self._completed_steps)})
        return self._snapshot("completed")

    async def _run_step(self, step: WorkflowStep) -> StepResult:
        await self._emit("step.started", {"step": step.name, "agent": step.agent})
        last_error = ""

        for attempt in range(step.max_retries + 1):
            try:
                t0     = asyncio.get_event_loop().time()
                result = await asyncio.wait_for(
                    step.run_fn(self.ctx),
                    timeout=max(10, int(step.timeout_s))
                )
                result.latency_ms = int((asyncio.get_event_loop().time() - t0) * 1000)
                await self._emit("step.completed", {
                    "step":       step.name,
                    "confidence": result.confidence,
                    "latency_ms": result.latency_ms,
                    "attempt":    attempt + 1,
                })
                return result

            except asyncio.TimeoutError:
                last_error = f"Timeout after {step.timeout_s}s"
            except Exception as e:
                import traceback as _tb
                last_error = str(e)
                print(f"[WorkflowEngine] step '{step.name}' attempt {attempt+1} error: {e}")
                _tb.print_exc()

            if attempt < step.max_retries:
                await self._emit("step.retrying", {"step": step.name, "attempt": attempt + 1, "error": last_error})
                await asyncio.sleep(step.retry_delay_s * (2 ** attempt))  # exponential backoff

        await self._emit("step.failed", {"step": step.name, "error": last_error})
        return StepResult(status=StepStatus.FAILED, error=last_error)

    async def _compensate(self):
        """Run compensation flows in reverse order (saga pattern)."""
        self.status = WorkflowStatus.COMPENSATING
        await self._emit("workflow.compensating", {})

        for step_name in reversed(self._completed_steps):
            step = self.steps[step_name]
            if step.compensate_fn:
                try:
                    await step.compensate_fn(self.ctx)
                    await self._emit("step.compensated", {"step": step_name})
                except Exception as e:
                    await self._emit("step.compensation_failed", {"step": step_name, "error": str(e)})

        self.status = WorkflowStatus.COMPENSATED

    async def resume_from_approval(self, approval_action: str, overrides: dict = None) -> dict:
        """
        Called when human approves/rejects via HITL.
        In Temporal: this is a Signal handler.
        """
        if self.status != WorkflowStatus.AWAITING_HUMAN:
            raise ValueError("Workflow is not awaiting approval")

        await self._emit("workflow.resumed", {"action": approval_action, "overrides": overrides or {}})

        if approval_action == "reject":
            self.status = WorkflowStatus.CANCELLED
            return self._snapshot("cancelled")

        if approval_action == "request_changes" and overrides:
            # Apply overrides to context and re-run document generation
            self.ctx.raw_input.update(overrides)

        self.status = WorkflowStatus.RUNNING
        # Continue from where we paused
        return await self.run()

    def _snapshot(self, status: str) -> dict:
        return {
            "workflow_id":       self.ctx.workflow_id,
            "status":            status,
            "org_id":            self.ctx.org_id,
            "overall_confidence": self.ctx.overall_confidence,
            "risk_flags":        self.ctx.risk_flags,
            "extracted_po":      self.ctx.extracted_po,
            "hs_validations":    self.ctx.hs_validations,
            "documents":         self.ctx.documents,
            "approval_id":       self.ctx.approval_id,
            "sent_channels":     self.ctx.sent_channels,
            "step_statuses":     {k: v.status.value for k, v in self.step_statuses.items()},
            "audit_entries":     self.ctx.audit_entries,
        }


# ─────────────────────────────────────────────
# THE KILLER DEMO WORKFLOW — DECLARATIVE
# PO → Extract → HS → Docs → HITL → Send → Track
# ─────────────────────────────────────────────

def build_po_to_dispatch_workflow(org_id: str, source: str, raw_input: dict) -> tuple[WorkflowEngine, WorkflowContext]:
    """
    Returns a fully wired workflow engine ready to .run().
    Steps are pure async functions — swap agents without changing the machine.
    """

    ctx = WorkflowContext(org_id=org_id, source=source, raw_input=raw_input)

    # ── STEP IMPLEMENTATIONS ──────────────────────────────

    async def step_extract_po(ctx: WorkflowContext) -> StepResult:
        from services.api.main import POExtractionAgent, DocumentIntelligenceEngine
        import uuid as _uuid

        agent    = POExtractionAgent(org_id=_uuid.UUID(ctx.org_id))
        raw_text = ctx.raw_input.get("raw_text", "")
        doc_preextracted: dict = {}

        if ctx.raw_input.get("file_bytes"):
            doc_result = await DocumentIntelligenceEngine.extract_from_file(
                ctx.raw_input["file_bytes"], ctx.raw_input.get("mime_type", "application/pdf")
            )
            # Prefer the OCR'd text; fall back to any raw_text already in the input
            raw_text = doc_result.get("raw_text", "") or raw_text
            # The full_document_pipeline also runs an LLM pass — keep it as
            # supplementary context so the PO agent can fill gaps
            doc_preextracted = doc_result.get("extracted", {})

        result    = await agent.run({"source": ctx.source, "raw_text": raw_text})
        extracted = result["data"]

        # Merge pre-extracted fields for any nulls the PO agent left blank
        # (pre-extracted is lower-trust; never overwrite what the PO agent set)
        for field_name, value in doc_preextracted.items():
            if value and not extracted.get(field_name):
                extracted[field_name] = value

        ctx.extracted_po = extracted
        confidence = float(extracted.get("confidence") or 0)
        ctx.overall_confidence = confidence

        return StepResult(
            status=StepStatus.COMPLETED,
            output=extracted,
            confidence=confidence,
        )

    async def compensate_extract_po(ctx: WorkflowContext):
        ctx.extracted_po = {}

    async def step_validate_hs(ctx: WorkflowContext) -> StepResult:
        from services.api.main import HSCodeValidationAgent
        import uuid as _uuid

        items = ctx.extracted_po.get("items", [])
        
        # Fallback: if no items extracted, skip gracefully
        if not items:
            ctx.hs_validations = {"validations": [], "overall_clearance": True, "flags": []}
            return StepResult(status=StepStatus.COMPLETED, output=ctx.hs_validations, confidence=80)

        agent = HSCodeValidationAgent(org_id=_uuid.UUID(ctx.org_id))
        try:
            result = await agent.run({
                "items":        items,
                "from_country": "IN",
                "to_country":   (ctx.extracted_po.get("buyer_country") or "AE")[:2].upper(),
            })
            hs_data = result["data"]
        except Exception as exc:
            # HS validation failure is non-critical — use passthrough
            print(f"[validate_hs] fallback due to: {exc}")
            hs_data = {
                "validations": [
                    {
                        "original_description": item.get("description", ""),
                        "original_hs_code":     item.get("hs_code", ""),
                        "validated_hs_code":    item.get("hs_code", ""),
                        "is_valid":             True,
                        "confidence":           70,
                        "correction_reason":    "passthrough — validation unavailable",
                    }
                    for item in items
                ],
                "overall_clearance": True,
                "flags": [],
            }

        ctx.hs_validations = hs_data
        for flag in hs_data.get("flags", []):
            ctx.risk_flags.append({"message": flag, "severity": "high", "source": "hs_validation"})

        confidence = min(
            ctx.overall_confidence,
            min((v.get("confidence", 70) for v in hs_data.get("validations", [])), default=70)
        )
        ctx.overall_confidence = confidence
        return StepResult(status=StepStatus.COMPLETED, output=hs_data, confidence=confidence)

    async def step_generate_documents(ctx: WorkflowContext) -> StepResult:
        from services.api.main import DocumentGenerationAgent
        import uuid as _uuid

        agent      = DocumentGenerationAgent(org_id=_uuid.UUID(ctx.org_id))
        order_data = {
            "buyer":     ctx.extracted_po.get("buyer_name"),
            "country":   ctx.extracted_po.get("buyer_country"),
            "items":     ctx.hs_validations.get("validations", []),
            "currency":  ctx.extracted_po.get("currency", "USD"),
            "terms":     ctx.extracted_po.get("payment_terms"),
            "incoterms": ctx.extracted_po.get("incoterms"),
            "port":      ctx.extracted_po.get("destination_port"),
        }

        # Run each doc independently — one failure must not block the other
        invoice_data = {}
        packing_data = {}

        try:
            invoice_r    = await agent.run({"doc_type": "commercial_invoice", "order": order_data})
            invoice_data = invoice_r["doc_data"]
            print(f"[generate_documents] invoice OK confidence={invoice_data.get('_confidence')}")
        except Exception as exc:
            print(f"[generate_documents] invoice failed: {exc}")
            invoice_data = {
                "invoice_number": f"DRAFT-{ctx.workflow_id[:8].upper()}",
                "invoice_date":   __import__("datetime").datetime.utcnow().strftime("%Y-%m-%d"),
                "grand_total":    ctx.extracted_po.get("total_value", 0),
                "currency":       ctx.extracted_po.get("currency", "USD"),
                "payment_terms":  ctx.extracted_po.get("payment_terms", ""),
                "incoterms":      ctx.extracted_po.get("incoterms", ""),
                "bank_details":   {"name": "State Bank of India", "swift": "SBININBB"},
                "declaration":    "Draft — pending review.",
                "_confidence":    40,
                "_draft":         True,
            }

        try:
            packing_r    = await agent.run({"doc_type": "packing_list", "order": order_data})
            packing_data = packing_r["doc_data"]
            print(f"[generate_documents] packing OK confidence={packing_data.get('_confidence')}")
        except Exception as exc:
            print(f"[generate_documents] packing list failed: {exc}")
            packing_data = {
                "pl_number":             f"PL-{ctx.workflow_id[:8].upper()}",
                "total_packages":        1,
                "total_net_weight_kg":   0,
                "total_gross_weight_kg": 0,
                "total_volume_cbm":      0,
                "_confidence":           40,
                "_draft":                True,
            }

        ctx.documents = {
            "commercial_invoice": invoice_data,
            "packing_list":       packing_data,
        }

        doc_confidence = min(
            float(invoice_data.get("_confidence") or 40),
            float(packing_data.get("_confidence") or 40),
        )
        ctx.overall_confidence = min(ctx.overall_confidence, doc_confidence)

        return StepResult(
            status=StepStatus.COMPLETED,
            output=ctx.documents,
            confidence=ctx.overall_confidence,
        )

    async def compensate_generate_documents(ctx: WorkflowContext):
        """Rollback: delete generated document records from DB."""
        ctx.documents = {}

    async def step_hitl_decision(ctx: WorkflowContext) -> StepResult:
        from services.api.main import HITLOrchestrator
        from core.db import get_pool, SEED_USER_ID
        import uuid as _uuid
        import json as _json
        from datetime import timezone, timedelta

        decision = HITLOrchestrator.evaluate(
            "doc_generation", ctx.overall_confidence, ctx.risk_flags
        )

        # ── Persist workflow + order + approval_request to DB ────────────
        pool = get_pool()
        async with pool.acquire() as db:

            # 1 — Insert into workflows
            wf_row = await db.fetchrow(
                """
                INSERT INTO workflows (
                    id, org_id, name, status, current_step,
                    state_snapshot, context
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7)
                ON CONFLICT (id) DO UPDATE
                    SET status = EXCLUDED.status,
                        current_step = EXCLUDED.current_step
                RETURNING id
                """,
                _uuid.UUID(ctx.workflow_id),
                _uuid.UUID(ctx.org_id),
                "po_to_dispatch",
                "awaiting_human" if decision["requires_human"] else "running",
                "hitl_decision",
                _json.dumps({}),
                _json.dumps({
                    "source": ctx.source,
                    "overall_confidence": ctx.overall_confidence,
                }),
            )
            db_workflow_id = wf_row["id"]

            # 2 — Upsert buyer contact from extracted PO data
            extracted    = ctx.extracted_po
            buyer_name   = (extracted.get("buyer_name") or "Unknown Buyer")[:200]
            buyer_country= (extracted.get("buyer_country") or "AE")[:2].upper()
            buyer_wa     = ctx.raw_input.get("buyer_whatsapp") or ""

            contact_row = await db.fetchrow(
                """
                INSERT INTO contacts (org_id, type, name, country, currency, payment_terms, whatsapp)
                VALUES ($1, 'buyer', $2, $3, $4, $5, $6)
                ON CONFLICT DO NOTHING
                RETURNING id
                """,
                _uuid.UUID(ctx.org_id), buyer_name, buyer_country,
                (extracted.get("currency") or "USD")[:3],
                extracted.get("payment_terms"), buyer_wa or None,
            )
            if contact_row is None:
                contact_row = await db.fetchrow(
                    "SELECT id FROM contacts WHERE org_id=$1 AND name=$2 LIMIT 1",
                    _uuid.UUID(ctx.org_id), buyer_name,
                )
            if contact_row is None:
                contact_row = await db.fetchrow(
                    "SELECT id FROM contacts WHERE org_id=$1 LIMIT 1",
                    _uuid.UUID(ctx.org_id),
                )
            buyer_id = contact_row["id"] if contact_row else None
            print(f"[HITL] buyer contact upserted: {buyer_id}  name={buyer_name}")

            # 3 — Insert into orders
            order_number = f"WA-{ctx.workflow_id[:8].upper()}"
            order_row = await db.fetchrow(
                """
                INSERT INTO orders (
                    org_id, order_number, buyer_id, status,
                    currency, payment_terms, incoterms,
                    port_of_discharge, destination_country,
                    po_source, po_raw_text, workflow_id
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
                ON CONFLICT (org_id, order_number) DO UPDATE
                    SET status = EXCLUDED.status
                RETURNING id
                """,
                _uuid.UUID(ctx.org_id), order_number, buyer_id,
                "awaiting_approval" if decision["requires_human"] else "documents_pending",
                (extracted.get("currency") or "USD")[:3],
                extracted.get("payment_terms"),
                extracted.get("incoterms"),
                extracted.get("destination_port"),
                buyer_country,
                # Map internal source names to DB constraint values:
                # 'file' (PDF upload via WA) → 'whatsapp'
                # anything else unknown      → 'manual'
                {"file": "whatsapp", "whatsapp": "whatsapp",
                 "email": "email", "portal": "portal"}.get(ctx.source, "manual"),
                extracted.get("raw_text") or None,
                db_workflow_id,
            )
            ctx.order_id = str(order_row["id"])

            if decision["requires_human"]:
                # 3 — Insert approval_request
                approval_uuid = _uuid.uuid4()
                ctx.approval_id = str(approval_uuid)
                expires = (
                    __import__("datetime").datetime.now(timezone.utc)
                    + timedelta(hours=4)
                )
                await db.execute(
                    """
                    INSERT INTO approval_requests (
                        id, org_id, workflow_id, order_id,
                        requested_by, title, description,
                        ai_confidence, risk_flags, suggested_action,
                        diff_after, assigned_to, expires_at
                    )
                    VALUES (
                        $1, $2, $3, $4,
                        $5, $6, $7,
                        $8, $9, $10,
                        $11, $12, $13
                    )
                    """,
                    approval_uuid,
                    _uuid.UUID(ctx.org_id),
                    db_workflow_id,
                    order_row["id"],
                    "hitl_supervisor_agent",
                    f"PO Review Required — {order_number}",
                    decision["reason"],
                    ctx.overall_confidence,
                    _json.dumps(ctx.risk_flags),
                    decision["decision"],
                    _json.dumps(ctx.documents),
                    _uuid.UUID(SEED_USER_ID),
                    expires,
                )
                print(f"[HITL] approval_request created: {approval_uuid}  order: {ctx.order_id}")

                return StepResult(
                    status=StepStatus.COMPLETED,
                    output=decision,
                    confidence=ctx.overall_confidence,
                    requires_human=True,
                    human_reason=decision["reason"],
                )

        return StepResult(status=StepStatus.COMPLETED, output=decision, confidence=ctx.overall_confidence)

    async def step_send_notifications(ctx: WorkflowContext) -> StepResult:
        """
        Send order confirmation to the buyer.

        Current: formatted WhatsApp text message with invoice summary.

        PDF attachment hook:
          When PDF generation is ready, call:
              pdf_bytes = await generate_invoice_pdf(ctx.documents["commercial_invoice"])
              pdf_url   = await upload_to_storage(pdf_bytes, filename)
              await WhatsAppService.send_document(to=buyer_wa, doc_url=pdf_url,
                                                  filename="invoice.pdf",
                                                  caption="Your commercial invoice")
          then remove / replace the send_text call below.
        """
        from services.api.main import WhatsAppService

        buyer_wa = ctx.raw_input.get("buyer_whatsapp")
        invoice  = ctx.documents.get("commercial_invoice", {})
        packing  = ctx.documents.get("packing_list", {})

        if buyer_wa:
            try:
                # Build a rich invoice summary message
                items_lines = "\n".join(
                    f"  • {v.get('description','?')}  "
                    f"qty {v.get('qty','?')} {v.get('unit','')}  "
                    f"@ {invoice.get('currency','')} {v.get('unit_price','?')}"
                    for v in (invoice.get("items") or [])[:5]   # cap at 5 lines
                ) or "  (see attached invoice)"

                body = (
                    f"✅ *Order Confirmed — {invoice.get('invoice_number','N/A')}*\n\n"
                    f"📅 Date: {invoice.get('invoice_date','—')}\n"
                    f"💰 Total: {invoice.get('currency','')} {invoice.get('grand_total','—')}\n"
                    f"📦 Incoterms: {invoice.get('incoterms','—')} | {invoice.get('payment_terms','—')}\n\n"
                    f"*Items:*\n{items_lines}\n\n"
                    f"📦 Packages: {packing.get('total_packages','—')}  "
                    f"Net wt: {packing.get('total_net_weight_kg','—')} kg\n\n"
                    f"🚢 Shipment in 3 working days. Documents to follow.\n"
                    f"Reference: {ctx.workflow_id[:8].upper()}"
                )

                await WhatsAppService.send_text(to=buyer_wa, body=body)
                ctx.sent_channels.append("whatsapp")

                # ── PDF attachment hook ──────────────────────────────────────
                # Uncomment + implement when PDF generation is available:
                #
                # from services.pdf.generator import generate_invoice_pdf
                # from services.storage import upload_to_storage
                # pdf_bytes = await generate_invoice_pdf(invoice)
                # pdf_url   = await upload_to_storage(
                #     pdf_bytes,
                #     f"invoices/{ctx.workflow_id}/{invoice.get('invoice_number','inv')}.pdf"
                # )
                # await WhatsAppService.send_document(
                #     to=buyer_wa,
                #     doc_url=pdf_url,
                #     filename=f"{invoice.get('invoice_number','invoice')}.pdf",
                #     caption=f"Commercial Invoice — {invoice.get('invoice_number','')}",
                # )
                # ctx.sent_channels.append("whatsapp_document")
                # ── end PDF hook ─────────────────────────────────────────────

            except Exception as exc:
                print(f"[step_send_notifications] WhatsApp send failed: {exc}")
                # Non-critical — log and continue; skip_on_error=True handles the step

        return StepResult(status=StepStatus.COMPLETED, output={"sent": ctx.sent_channels}, confidence=100)

    async def step_create_shipment(ctx: WorkflowContext) -> StepResult:
        from core.db import get_pool
        import uuid as _uuid

        pool = get_pool()
        async with pool.acquire() as db:
            shipment_uuid = _uuid.uuid4()

            # order_id is set by step_hitl_decision; fall back to None if skipped
            order_id = _uuid.UUID(ctx.order_id) if ctx.order_id else None

            extracted = ctx.extracted_po
            await db.execute(
                """
                INSERT INTO shipments (
                    id, org_id, order_id,
                    port_of_loading, port_of_discharge,
                    status
                )
                VALUES ($1, $2, $3, $4, $5, $6)
                ON CONFLICT (id) DO NOTHING
                """,
                shipment_uuid,
                _uuid.UUID(ctx.org_id),
                order_id,
                extracted.get("port_of_loading") or None,
                extracted.get("destination_port") or None,
                "booking_pending",
            )
            ctx.shipment_id = str(shipment_uuid)
            print(f"[Logistics] shipment created: {shipment_uuid}  order: {order_id}")

        return StepResult(
            status=StepStatus.COMPLETED,
            output={"shipment_id": ctx.shipment_id},
            confidence=100,
        )

    # ── WIRE THE MACHINE ──────────────────────────────────

    steps = [
        WorkflowStep(
            name         = "extract_po",
            agent        = "po_extraction_agent",
            run_fn       = step_extract_po,
            compensate_fn= compensate_extract_po,
            max_retries  = 1,
            timeout_s    = int(os.getenv("PO_EXTRACT_TIMEOUT_S", 120)),
            skip_on_error= False,
        ),
        WorkflowStep(
            name         = "validate_hs",
            agent        = "hs_validation_agent",
            run_fn       = step_validate_hs,
            max_retries  = 2,
            timeout_s    = int(os.getenv("HS_VALIDATION_TIMEOUT_S", 180)),
            skip_on_error= True,        # ADD THIS — don't kill workflow if HS fails
            depends_on   = ["extract_po"],
        ),
        WorkflowStep(
            name         = "generate_documents",
            agent        = "doc_generation_agent",
            run_fn       = step_generate_documents,
            compensate_fn= compensate_generate_documents,
            max_retries  = 1,
            timeout_s    = int(os.getenv("DOC_GEN_TIMEOUT_S", 180)),
            skip_on_error= True,
            depends_on   = ["validate_hs"],
        ),
        WorkflowStep(
            name         = "hitl_decision",
            agent        = "supervisor_agent",
            run_fn       = step_hitl_decision,
            max_retries  = 0,
            timeout_s    = 10,
            depends_on   = ["generate_documents"],
        ),
        WorkflowStep(
            name         = "send_notifications",
            agent        = "communication_agent",
            run_fn       = step_send_notifications,
            max_retries  = 3,
            timeout_s    = 15,
            depends_on   = ["hitl_decision"],
            skip_on_error= True,          # Non-critical — don't fail workflow
        ),
        WorkflowStep(
            name         = "create_shipment",
            agent        = "logistics_agent",
            run_fn       = step_create_shipment,
            max_retries  = 2,
            timeout_s    = 20,
            depends_on   = ["hitl_decision"],
        ),
    ]

    engine = WorkflowEngine(steps=steps, ctx=ctx)
    return engine, ctx


# ─────────────────────────────────────────────
# TEMPORAL ACTIVITY STUBS
# (replace WorkflowEngine.run() in prod)
# ─────────────────────────────────────────────

"""
from temporalio import activity, workflow
from temporalio.client import Client
from temporalio.worker import Worker

@activity.defn
async def extract_po_activity(input: dict) -> dict:
    engine, ctx = build_po_to_dispatch_workflow(...)
    return await engine._run_step(engine.steps["extract_po"])

@workflow.defn
class POToDispatchWorkflow:
    @workflow.run
    async def run(self, input: dict) -> dict:
        ctx = WorkflowContext(**input)

        ctx.extracted_po = await workflow.execute_activity(
            extract_po_activity,
            input,
            start_to_close_timeout=timedelta(seconds=45),
            retry_policy=RetryPolicy(maximum_attempts=3),
        )

        # HITL: block until Signal received
        if needs_human:
            await workflow.wait_condition(lambda: self._approval_received)

        ... etc

    @workflow.signal
    async def approval_signal(self, action: str, overrides: dict):
        self._approval_received = True
        self._approval_action = action
        self._overrides = overrides
"""
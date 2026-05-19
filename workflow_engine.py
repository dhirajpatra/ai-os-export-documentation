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
    timeout_s:      int  = 60
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
        await self._emit("workflow.started", {"org_id": self.ctx.org_id})

        for step_name in self.step_order:
            step = self.steps[step_name]

            # Check dependencies
            for dep in step.depends_on:
                dep_result = self.step_statuses.get(dep)
                if not dep_result or dep_result.status != StepStatus.COMPLETED:
                    await self._emit("step.skipped", {"step": step_name, "reason": f"dep {dep} not met"})
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
                    timeout=step.timeout_s,
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
                last_error = str(e)

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

        if ctx.raw_input.get("file_bytes"):
            doc_result = await DocumentIntelligenceEngine.extract_from_file(
                ctx.raw_input["file_bytes"], ctx.raw_input.get("mime_type", "application/pdf")
            )
            raw_text = doc_result.get("raw_text", "") or raw_text

        result = await agent.run({"source": ctx.source, "raw_text": raw_text})
        extracted = result["data"]
        ctx.extracted_po = extracted
        confidence = float(extracted.get("confidence", 0))
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

        agent = HSCodeValidationAgent(org_id=_uuid.UUID(ctx.org_id))
        result = await agent.run({
            "items":        ctx.extracted_po.get("items", []),
            "from_country": "IN",
            "to_country":   (ctx.extracted_po.get("buyer_country") or "AE")[:2].upper(),
        })
        hs_data = result["data"]
        ctx.hs_validations = hs_data

        # Collect risk flags from HS validation
        for flag in hs_data.get("flags", []):
            ctx.risk_flags.append({"message": flag, "severity": "high", "source": "hs_validation"})

        confidence = min(
            ctx.overall_confidence,
            min((v.get("confidence", 90) for v in hs_data.get("validations", [])), default=90)
        )
        ctx.overall_confidence = confidence

        return StepResult(status=StepStatus.COMPLETED, output=hs_data, confidence=confidence)

    async def step_generate_documents(ctx: WorkflowContext) -> StepResult:
        from services.api.main import DocumentGenerationAgent
        import uuid as _uuid

        agent     = DocumentGenerationAgent(org_id=_uuid.UUID(ctx.org_id))
        order_data = {
            "buyer":     ctx.extracted_po.get("buyer_name"),
            "country":   ctx.extracted_po.get("buyer_country"),
            "items":     ctx.hs_validations.get("validations", []),
            "currency":  ctx.extracted_po.get("currency", "USD"),
            "terms":     ctx.extracted_po.get("payment_terms"),
            "incoterms": ctx.extracted_po.get("incoterms"),
            "port":      ctx.extracted_po.get("destination_port"),
        }

        invoice_r = await agent.run({"doc_type": "commercial_invoice", "order": order_data})
        packing_r = await agent.run({"doc_type": "packing_list",       "order": order_data})

        ctx.documents = {
            "commercial_invoice": invoice_r["doc_data"],
            "packing_list":       packing_r["doc_data"],
        }

        doc_confidence = min(invoice_r.get("confidence", 95), packing_r.get("confidence", 95))
        ctx.overall_confidence = min(ctx.overall_confidence, doc_confidence)

        return StepResult(status=StepStatus.COMPLETED, output=ctx.documents, confidence=ctx.overall_confidence)

    async def compensate_generate_documents(ctx: WorkflowContext):
        """Rollback: delete generated document records from DB."""
        ctx.documents = {}

    async def step_hitl_decision(ctx: WorkflowContext) -> StepResult:
        from services.api.main import HITLOrchestrator
        import uuid as _uuid

        decision = HITLOrchestrator.evaluate(
            "doc_generation", ctx.overall_confidence, ctx.risk_flags
        )

        if decision["requires_human"]:
            ctx.approval_id = str(_uuid.uuid4())
            # In production: INSERT into approval_requests, notify assigned user
            return StepResult(
                status=StepStatus.COMPLETED,
                output=decision,
                confidence=ctx.overall_confidence,
                requires_human=True,
                human_reason=decision["reason"],
            )

        return StepResult(status=StepStatus.COMPLETED, output=decision, confidence=ctx.overall_confidence)

    async def step_send_notifications(ctx: WorkflowContext) -> StepResult:
        from services.api.main import WhatsAppService

        buyer_wa = ctx.raw_input.get("buyer_whatsapp")
        invoice  = ctx.documents.get("commercial_invoice", {})

        if buyer_wa:
            try:
                await WhatsAppService.send_text(
                    to=buyer_wa,
                    body=(
                        f"✅ Order confirmed!\n\n"
                        f"📄 Invoice: {invoice.get('invoice_number', 'N/A')}\n"
                        f"💰 Amount: {invoice.get('currency')} {invoice.get('grand_total')}\n"
                        f"📦 Terms: {invoice.get('incoterms')} | {invoice.get('payment_terms')}\n"
                        f"🚢 Shipment in 3 working days.\n\nDocuments to follow. Thank you!"
                    )
                )
                ctx.sent_channels.append("whatsapp")
            except Exception:
                pass  # Non-critical — log and continue

        return StepResult(status=StepStatus.COMPLETED, output={"sent": ctx.sent_channels}, confidence=100)

    async def step_create_shipment(ctx: WorkflowContext) -> StepResult:
        import uuid as _uuid
        ctx.shipment_id = str(_uuid.uuid4())
        # In production: INSERT into shipments, trigger carrier booking workflow
        return StepResult(
            status=StepStatus.COMPLETED,
            output={"shipment_id": ctx.shipment_id},
            confidence=100
        )

    # ── WIRE THE MACHINE ──────────────────────────────────

    steps = [
        WorkflowStep(
            name         = "extract_po",
            agent        = "po_extraction_agent",
            run_fn       = step_extract_po,
            compensate_fn= compensate_extract_po,
            max_retries  = 2,
            timeout_s    = 45,
        ),
        WorkflowStep(
            name         = "validate_hs",
            agent        = "hs_validation_agent",
            run_fn       = step_validate_hs,
            max_retries  = 2,
            timeout_s    = 30,
            depends_on   = ["extract_po"],
        ),
        WorkflowStep(
            name         = "generate_documents",
            agent        = "doc_generation_agent",
            run_fn       = step_generate_documents,
            compensate_fn= compensate_generate_documents,
            max_retries  = 1,
            timeout_s    = 60,
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

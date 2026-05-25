"""
TradeOS — PO Workflow (LangGraph orchestration)
================================================
Flow:
  po_extraction
      ↓
  clarification_check  ──(missing critical fields)──→ ask_buyer → END (wait for reply)
      ↓ (all good)
  hs_validation
      ↓
  doc_generation
      ↓
  hitl_evaluation
      ↓
  dispatch / awaiting_approval → END
"""

import uuid
import operator
from typing import TypedDict, Annotated, Optional
from datetime import datetime
from langgraph.graph import StateGraph, START, END

from services.sse.sse_bus import push_event, close_channel
from services.agents.po_extraction import POExtractionAgent
from services.agents.hs_validation import HSCodeValidationAgent
from services.agents.doc_generation import DocumentGenerationAgent
from services.integrations.whatsapp import WhatsAppService
from services.api.main import DocumentIntelligenceEngine, HITLOrchestrator
from core.config import cfg
from core.prompt_registry import ClarificationEngine


# ─────────────────────────────────────────────
# WORKFLOW STATE
# ─────────────────────────────────────────────

class WorkflowState(TypedDict):
    # Inputs
    org_id:         uuid.UUID
    source:         str
    raw_text:       Optional[str]
    file_bytes:     Optional[bytes]
    buyer_whatsapp: Optional[str]
    buyer_email:    Optional[str]
    workflow_id:    str

    # Extraction outputs
    extracted:          dict
    overall_confidence: float

    # Clarification
    clarification_result:   dict    # output of ClarificationEngine.check()
    clarification_sent:     bool    # True if we already asked buyer
    pending_questions:      list    # questions waiting for buyer reply

    # Processing outputs
    hs_data:        dict
    risk_flags:     list
    documents:      dict
    hitl_decision:  dict
    approval_id:    Optional[str]
    status:         str

    # steps_log uses operator.add so each node appends
    steps_log: Annotated[list, operator.add]


# ─────────────────────────────────────────────
# WORKFLOW CLASS
# ─────────────────────────────────────────────

class KillerDemoWorkflow:
    """
    LangGraph-orchestrated PO → document generation workflow.
    Clarification-first: asks buyer for missing info before processing.
    """

    def __init__(self, org_id: uuid.UUID, db=None):
        self.org_id = org_id
        self.db     = db
        self.app    = self._build_graph()

    # ── Graph construction ────────────────────────────────

    def _build_graph(self):
        workflow = StateGraph(WorkflowState)

        workflow.add_node("po_extraction",       self.node_po_extraction)
        workflow.add_node("clarification_check", self.node_clarification_check)
        workflow.add_node("ask_buyer",           self.node_ask_buyer)
        workflow.add_node("hs_validation",       self.node_hs_validation)
        workflow.add_node("doc_generation",      self.node_doc_generation)
        workflow.add_node("hitl_evaluation",     self.node_hitl_evaluation)
        workflow.add_node("dispatch",            self.node_dispatch)

        workflow.add_edge(START,            "po_extraction")
        workflow.add_edge("po_extraction",  "clarification_check")

        # After clarification check: ask buyer OR proceed
        workflow.add_conditional_edges(
            "clarification_check",
            self.route_after_clarification,
            {
                "ask_buyer":    "ask_buyer",
                "hs_validation":"hs_validation",
            }
        )

        # ask_buyer always ends — workflow resumes when buyer replies
        workflow.add_edge("ask_buyer", END)

        workflow.add_edge("hs_validation",   "doc_generation")
        workflow.add_edge("doc_generation",  "hitl_evaluation")

        # After HITL: dispatch or wait for human approval
        workflow.add_conditional_edges(
            "hitl_evaluation",
            self.route_after_hitl,
            {
                "dispatch":           "dispatch",
                "awaiting_approval":  END,
            }
        )

        workflow.add_edge("dispatch", END)

        return workflow.compile()

    # ── Helpers ──────────────────────────────────────────

    async def _log(self, state: WorkflowState, step: str, status: str, data: dict | None = None) -> list:
        entry = {
            "step":   step,
            "status": status,
            "ts":     datetime.utcnow().isoformat(),
            "data":   data or {},
        }
        try:
            from core.kafka_producer import send_event
            await send_event("workflow_events", f"workflow.{step}.{status}", {
                "workflow_id": state.get("workflow_id"),
                "org_id":      str(self.org_id),
                **entry,
            })
        except Exception as exc:
            print(f"[Kafka] log failed: {exc}")
        return [entry]

    # ── Nodes ─────────────────────────────────────────────

    async def node_po_extraction(self, state: WorkflowState) -> dict:
        wf_id = state["workflow_id"]
        await push_event(wf_id, "po_extraction", "running")

        logs  = await self._log(state, "po_extraction", "running")
        agent = POExtractionAgent(self.org_id)

        raw_text = state.get("raw_text")
        if state.get("file_bytes"):
            doc_intel = await DocumentIntelligenceEngine.extract_from_file(
                state["file_bytes"], "application/pdf"
            )
            raw_text = doc_intel["raw_text"]

        extraction = await agent.run({
            "source":   state["source"],
            "raw_text": raw_text or "",
        })
        extracted = extraction["data"]

        done_data = {
            "confidence": extracted.get("confidence"),
            "items":      len(extracted.get("items", [])),
            "warnings":   extracted.get("warnings", []),
            "buyer_name": extracted.get("buyer_name"),
            "destination_port": extracted.get("destination_port"),
        }
        logs += await self._log(state, "po_extraction", "done", done_data)
        await push_event(wf_id, "po_extraction", "done", done_data)

        return {
            "extracted":          extracted,
            "overall_confidence": float(extracted.get("confidence") or cfg.CONFIDENCE_THRESHOLD_FALLBACK),
            "steps_log":          logs,
        }

    async def node_clarification_check(self, state: WorkflowState) -> dict:
        """
        Inspect extracted data.
        Use ClarificationEngine to find missing fields.
        Collect questions from extracted.requires_clarification AND ClarificationEngine.
        """
        wf_id = state["workflow_id"]
        await push_event(wf_id, "clarification_check", "running")

        logs      = await self._log(state, "clarification_check", "running")
        extracted = state["extracted"]
        source    = state.get("source", "whatsapp")

        # 1 — Rule-based check from ClarificationEngine
        engine_result = ClarificationEngine.check(extracted, source=source)

        # 2 — LLM-generated clarification questions from the prompt schema
        llm_clarifications = extracted.get("requires_clarification", [])
        llm_questions = [
            c["question"] for c in llm_clarifications
            if c.get("question")
        ]

        # 3 — Merge: engine questions first (blocking), then LLM questions
        all_questions = engine_result["questions"] + [
            q for q in llm_questions
            if q not in engine_result["questions"]
        ]

        # 4 — Determine blocking fields
        blocking_fields = engine_result["blocking_fields"] + [
            c["field"] for c in llm_clarifications
            if c.get("blocking") and c["field"] not in engine_result["blocking_fields"]
        ]

        clarification_result = {
            **engine_result,
            "questions":       all_questions,
            "blocking_fields": blocking_fields,
            "blocked":         len(blocking_fields) > 0,
            "can_proceed":     len(blocking_fields) == 0,
        }

        done_data = {
            "blocked":         clarification_result["blocked"],
            "can_proceed":     clarification_result["can_proceed"],
            "question_count":  len(all_questions),
            "blocking_fields": blocking_fields,
        }
        logs += await self._log(state, "clarification_check", "done", done_data)
        await push_event(wf_id, "clarification_check", "done", done_data)

        return {
            "clarification_result": clarification_result,
            "pending_questions":    all_questions,
            "steps_log":            logs,
        }

    async def node_ask_buyer(self, state: WorkflowState) -> dict:
        """
        Send clarification questions to buyer via WhatsApp.
        Workflow pauses here — resumes when buyer replies.
        """
        wf_id     = state["workflow_id"]
        questions = state.get("pending_questions", [])
        wa        = state.get("buyer_whatsapp")

        await push_event(wf_id, "ask_buyer", "running", {"question_count": len(questions)})
        logs = await self._log(state, "ask_buyer", "running")

        if wa and questions:
            # Build consolidated WhatsApp message
            msg = ClarificationEngine.build_whatsapp_question(
                missing_fields=state["clarification_result"].get("blocking_fields", [])
                              + state["clarification_result"].get("clarification_fields", []),
                extracted=state["extracted"],
            )
            # Fallback: join questions directly if build_whatsapp_question returns empty
            if not msg:
                lines = ["To process your order, could you please confirm:\n"]
                for i, q in enumerate(questions[:5], 1):
                    lines.append(f"{i}. {q}")
                lines.append("\nOnce confirmed, we'll process your order right away. 📦")
                msg = "\n".join(lines)

            try:
                await WhatsAppService.send_text(to=wa, body=msg)
                print(f"[ask_buyer] Sent {len(questions)} clarification question(s) to {wa}")
            except Exception as exc:
                print(f"[ask_buyer] WhatsApp send failed: {exc}")

        paused_data = {
            "questions_sent": len(questions),
            "buyer_wa":       wa,
            "status":         "waiting_for_buyer_reply",
        }
        logs += await self._log(state, "ask_buyer", "paused", paused_data)
        await push_event(wf_id, "ask_buyer", "paused", paused_data)

        return {
            "clarification_sent": True,
            "status":             "awaiting_clarification",
            "steps_log":          logs,
        }

    async def node_hs_validation(self, state: WorkflowState) -> dict:
        wf_id = state["workflow_id"]
        await push_event(wf_id, "hs_validation", "running")

        logs      = await self._log(state, "hs_validation", "running")
        agent     = HSCodeValidationAgent(self.org_id)
        extracted = state["extracted"]

        buyer_country = extracted.get("buyer_country") or "AE"
        to_country    = buyer_country[:2].upper()

        hs_result  = await agent.run({
            "items":        extracted.get("items", []),
            "from_country": "IN",
            "to_country":   to_country,
        })
        hs_data    = hs_result["data"]
        risk_flags = [{"message": f, "severity": "high"} for f in hs_data.get("flags", [])]

        # Collect any HS-level clarification questions
        hs_questions = []
        for v in hs_data.get("validations", []):
            for c in v.get("requires_clarification", []):
                if c.get("question") and c["question"] not in hs_questions:
                    hs_questions.append(c["question"])

        done_data = {
            "clearance":         hs_data.get("overall_clearance"),
            "flags":             len(risk_flags),
            "hs_clarifications": len(hs_questions),
            "items_validated":   len(hs_data.get("validations", [])),
        }
        logs += await self._log(state, "hs_validation", "done", done_data)
        await push_event(wf_id, "hs_validation", "done", done_data)

        # If HS flagged blocking clarifications, add to pending
        existing_pending = state.get("pending_questions", [])
        merged_pending   = existing_pending + [q for q in hs_questions if q not in existing_pending]

        return {
            "hs_data":           hs_data,
            "risk_flags":        risk_flags,
            "pending_questions": merged_pending,
            "steps_log":         logs,
        }

    async def node_doc_generation(self, state: WorkflowState) -> dict:
        wf_id = state["workflow_id"]
        await push_event(wf_id, "doc_generation", "running")

        logs      = await self._log(state, "doc_generation", "running")
        agent     = DocumentGenerationAgent(self.org_id)
        extracted = state["extracted"]
        hs_data   = state["hs_data"]

        order_data = {
            "buyer":     extracted.get("buyer_name"),
            "country":   extracted.get("buyer_country"),
            "items":     hs_data.get("validations", []),
            "currency":  extracted.get("currency", "USD"),
            "terms":     extracted.get("payment_terms"),
            "incoterms": extracted.get("incoterms"),
            "port":      extracted.get("destination_port"),
        }

        invoice_data = {}
        packing_data = {}

        try:
            inv_r        = await agent.run({"doc_type": "commercial_invoice", "order": order_data})
            invoice_data = inv_r["doc_data"]
            print(f"[doc_generation] invoice OK confidence={invoice_data.get('_confidence')}")
        except Exception as exc:
            print(f"[doc_generation] invoice failed: {exc}")
            invoice_data = {
                "invoice_number": f"DRAFT-{state['workflow_id'][:8].upper()}",
                "invoice_date":   datetime.utcnow().strftime("%Y-%m-%d"),
                "grand_total":    extracted.get("total_value", 0),
                "currency":       extracted.get("currency", "USD"),
                "payment_terms":  extracted.get("payment_terms", ""),
                "bank_details":   {"name": "State Bank of India", "swift": "SBININBB"},
                "declaration":    "Draft — pending review.",
                "_confidence":    cfg.CONFIDENCE_THRESHOLD_FALLBACK,
                "_draft":         True,
            }

        try:
            pk_r         = await agent.run({"doc_type": "packing_list", "order": order_data})
            packing_data = pk_r["doc_data"]
            print(f"[doc_generation] packing OK confidence={packing_data.get('_confidence')}")
        except Exception as exc:
            print(f"[doc_generation] packing failed: {exc}")
            packing_data = {
                "pl_number":             f"PL-{state['workflow_id'][:8].upper()}",
                "total_packages":        1,
                "total_net_weight_kg":   0,
                "total_gross_weight_kg": 0,
                "_confidence":           cfg.CONFIDENCE_THRESHOLD_FALLBACK,
                "_draft":                True,
            }

        # Collect doc-level clarification questions
        doc_questions = []
        for field_list in [
            invoice_data.get("_missing_fields", []),
            packing_data.get("_missing_fields", []),
        ]:
            for c in field_list:
                if c.get("question") and c["question"] not in doc_questions:
                    doc_questions.append(c["question"])

        doc_confidence = min(
            float(invoice_data.get("_confidence") or cfg.CONFIDENCE_THRESHOLD_FALLBACK),
            float(packing_data.get("_confidence") or cfg.CONFIDENCE_THRESHOLD_FALLBACK),
        )
        new_confidence = min(state["overall_confidence"], doc_confidence)

        existing_pending = state.get("pending_questions", [])
        merged_pending   = existing_pending + [q for q in doc_questions if q not in existing_pending]

        done_data = {
            "docs":               ["commercial_invoice", "packing_list"],
            "confidence":         new_confidence,
            "doc_clarifications": len(doc_questions),
            "invoice_number":     invoice_data.get("invoice_number"),
            "grand_total":        invoice_data.get("grand_total"),
            "currency":           invoice_data.get("currency", "USD"),
        }
        logs += await self._log(state, "doc_generation", "done", done_data)
        await push_event(wf_id, "doc_generation", "done", done_data)

        return {
            "documents": {
                "commercial_invoice": invoice_data,
                "packing_list":       packing_data,
            },
            "overall_confidence": new_confidence,
            "pending_questions":  merged_pending,
            "steps_log":          logs,
        }

    async def node_hitl_evaluation(self, state: WorkflowState) -> dict:
        wf_id = state["workflow_id"]
        await push_event(wf_id, "hitl_evaluation", "running")

        logs          = await self._log(state, "hitl_evaluation", "running")
        hitl_decision = HITLOrchestrator.evaluate(
            "doc_generation",
            state["overall_confidence"],
            state["risk_flags"],
        )
        logs += await self._log(state, "hitl_evaluation", "done", hitl_decision)

        approval_required = hitl_decision["requires_human"]
        approval_id       = str(uuid.uuid4()) if approval_required else None

        done_data = {
            "decision":       hitl_decision["decision"],
            "requires_human": approval_required,
            "approval_id":    approval_id,
            "reason":         hitl_decision["reason"],
            "confidence":     state["overall_confidence"],
        }
        await push_event(wf_id, "hitl_evaluation", "done", done_data)

        # If there are pending clarification questions AND human review triggered,
        # send them now as part of the review notification
        pending = state.get("pending_questions", [])
        wa      = state.get("buyer_whatsapp")

        if approval_required:
            # Build notification with optional clarification questions
            if wa:
                if pending:
                    # Send clarification questions bundled with review status
                    lines = [
                        f"✅ *PO Received & Processed!*\n",
                        f"🎯 Confidence: {state['overall_confidence']:.0f}%",
                        f"📋 Status: Under Review",
                        f"Reference ID: `{approval_id}`\n",
                        "While our team reviews your order, could you also confirm:\n",
                    ]
                    for i, q in enumerate(pending[:3], 1):
                        lines.append(f"{i}. {q}")
                    lines.append("\nThis will help us finalize your documents faster. 📦")
                    msg = "\n".join(lines)
                else:
                    msg = (
                        f"✅ *PO Received & Processed!*\n\n"
                        f"🎯 Confidence: {state['overall_confidence']:.0f}%\n"
                        f"📋 Status: Under Review\n\n"
                        f"⏳ Our team is reviewing your order. "
                        f"You'll receive the documents shortly.\n"
                        f"Reference ID: `{approval_id}`"
                    )
                try:
                    await WhatsAppService.send_text(to=wa, body=msg)
                except Exception as exc:
                    print(f"[hitl_evaluation] WhatsApp notify failed: {exc}")

            paused_data = {
                "approval_id": approval_id,
                "decision":    hitl_decision["decision"],
                "reason":      hitl_decision["reason"],
                "confidence":  state["overall_confidence"],
            }
            logs += await self._log(state, "awaiting_human", "paused", paused_data)
            await push_event(wf_id, "awaiting_human", "paused", paused_data)

        return {
            "hitl_decision": hitl_decision,
            "approval_id":   approval_id,
            "status":        "awaiting_approval" if approval_required else "completed",
            "steps_log":     logs,
        }

    async def node_dispatch(self, state: WorkflowState) -> dict:
        wf_id = state["workflow_id"]
        await push_event(wf_id, "dispatch", "running")

        logs = await self._log(state, "dispatch", "running")
        wa   = state.get("buyer_whatsapp")

        if wa:
            invoice_data = state["documents"].get("commercial_invoice", {})
            pending      = state.get("pending_questions", [])

            lines = [
                f"✅ Your order has been confirmed and documents are ready.\n",
                f"Order: {invoice_data.get('invoice_number', 'N/A')}",
                f"Amount: {invoice_data.get('currency', 'USD')} {invoice_data.get('grand_total', 0)}",
                f"Terms: {invoice_data.get('payment_terms', '')}",
                f"ETA: 3 working days\n",
                "Documents will follow shortly. Thank you! 🚢",
            ]

            # Append any non-blocking clarification questions
            if pending:
                lines.append("\nP.S. To improve future orders, could you also share:")
                for i, q in enumerate(pending[:2], 1):
                    lines.append(f"   {i}. {q}")

            try:
                await WhatsAppService.send_text(to=wa, body="\n".join(lines))
            except Exception as exc:
                print(f"[dispatch] WhatsApp send failed: {exc}")

        done_data = {"channel": "whatsapp"}
        logs += await self._log(state, "dispatch", "done", done_data)
        await push_event(wf_id, "dispatch", "done", done_data)

        return {"steps_log": logs}

    # ── Routing functions ─────────────────────────────────

    def route_after_clarification(self, state: WorkflowState) -> str:
        result = state.get("clarification_result", {})
        if result.get("blocked"):
            return "ask_buyer"
        return "hs_validation"

    def route_after_hitl(self, state: WorkflowState) -> str:
        if state["hitl_decision"].get("requires_human"):
            return "awaiting_approval"
        return "dispatch"

    # ── Public execute interface ──────────────────────────

    async def execute(
        self,
        source:         str,
        raw_text:       str   | None = None,
        file_bytes:     bytes | None = None,
        buyer_whatsapp: str   | None = None,
        buyer_email:    str   | None = None,
    ) -> dict:

        initial_state: WorkflowState = {
            "org_id":               self.org_id,
            "source":               source,
            "raw_text":             raw_text,
            "file_bytes":           file_bytes,
            "buyer_whatsapp":       buyer_whatsapp,
            "buyer_email":          buyer_email,
            "workflow_id":          str(uuid.uuid4()),
            "steps_log":            [],
            "extracted":            {},
            "overall_confidence":   100.0,
            "clarification_result": {},
            "clarification_sent":   False,
            "pending_questions":    [],
            "hs_data":              {},
            "risk_flags":           [],
            "documents":            {},
            "hitl_decision":        {},
            "approval_id":          None,
            "status":               "running",
        }

        final_state = await self.app.ainvoke(initial_state)

        # Signal SSE consumers that the workflow is complete
        await close_channel(initial_state["workflow_id"])

        return {
            "workflow_id":        final_state["workflow_id"],
            "status":             final_state.get("status", "unknown"),
            "approval_id":        final_state.get("approval_id"),
            "hitl_decision":      final_state.get("hitl_decision"),
            "overall_confidence": final_state.get("overall_confidence"),
            "steps":              final_state.get("steps_log", []),
            "extracted_order":    final_state.get("extracted"),
            "hs_validation":      final_state.get("hs_data"),
            "documents":          final_state.get("documents"),
            "risk_flags":         final_state.get("risk_flags"),
            "clarification":      final_state.get("clarification_result"),
            "pending_questions":  final_state.get("pending_questions", []),
        }

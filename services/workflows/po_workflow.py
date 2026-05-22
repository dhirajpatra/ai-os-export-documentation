import uuid
import operator
from typing import TypedDict, Annotated, Optional, Any
from datetime import datetime
from langgraph.graph import StateGraph, START, END

from services.agents.po_extraction import POExtractionAgent
from services.agents.hs_validation import HSCodeValidationAgent
from services.agents.doc_generation import DocumentGenerationAgent
from services.integrations.whatsapp import WhatsAppService
from services.api.main import DocumentIntelligenceEngine, HITLOrchestrator
from core.config import cfg

class WorkflowState(TypedDict):
    org_id: uuid.UUID
    source: str
    raw_text: Optional[str]
    file_bytes: Optional[bytes]
    buyer_whatsapp: Optional[str]
    buyer_email: Optional[str]
    
    # Outputs
    extracted: dict
    hs_data: dict
    risk_flags: list
    overall_confidence: float
    documents: dict
    hitl_decision: dict
    approval_id: Optional[str]
    status: str
    workflow_id: str
    
    # We use operator.add so steps_log is appended across nodes
    steps_log: Annotated[list, operator.add]


class KillerDemoWorkflow:
    """The workflow that closes deals. Decoupled and distributed agent calling, orchestrated by LangGraph."""
    
    def __init__(self, org_id: uuid.UUID, db=None):
        self.org_id = org_id
        self.db = db
        self.app = self._build_graph()

    def _build_graph(self):
        workflow = StateGraph(WorkflowState)
        
        workflow.add_node("po_extraction", self.node_po_extraction)
        workflow.add_node("hs_validation", self.node_hs_validation)
        workflow.add_node("doc_generation", self.node_doc_generation)
        workflow.add_node("hitl_evaluation", self.node_hitl_evaluation)
        workflow.add_node("dispatch", self.node_dispatch)
        
        workflow.add_edge(START, "po_extraction")
        workflow.add_edge("po_extraction", "hs_validation")
        workflow.add_edge("hs_validation", "doc_generation")
        workflow.add_edge("doc_generation", "hitl_evaluation")
        
        # Conditional edge based on HITL decision
        workflow.add_conditional_edges(
            "hitl_evaluation",
            self.route_after_hitl,
            {
                "dispatch": "dispatch",
                "awaiting_approval": END
            }
        )
        
        workflow.add_edge("dispatch", END)
        
        return workflow.compile()

    async def _emit_log(self, state: WorkflowState, step: str, status: str, data: dict | None = None) -> list:
        entry = {"step": step, "status": status, "ts": datetime.utcnow().isoformat(), "data": data or {}}
        try:
            from core.kafka_producer import send_event
            await send_event("workflow_events", f"workflow.{step}.{status}", {
                "workflow_id": state.get("workflow_id"),
                "org_id": str(self.org_id),
                **entry
            })
        except Exception as exc:
            print(f"[Kafka Logging] Failed to send log: {exc}")
        return [entry]

    async def node_po_extraction(self, state: WorkflowState):
        log_entries = await self._emit_log(state, "po_extraction", "running")
        agent = POExtractionAgent(self.org_id)
        
        raw_text = state.get("raw_text")
        if state.get("file_bytes"):
            doc_intel = await DocumentIntelligenceEngine.extract_from_file(state["file_bytes"], "application/pdf")
            raw_text = doc_intel["raw_text"]

        extraction = await agent.run({"source": state["source"], "raw_text": raw_text or ""})
        extracted = extraction["data"]
        
        log_entries.extend(await self._emit_log(state, "po_extraction", "done", {
            "confidence": extracted.get("confidence"),
            "items": len(extracted.get("items", []))
        }))
        
        return {
            "extracted": extracted,
            "overall_confidence": extracted.get("confidence", cfg.CONFIDENCE_DEFAULT_FALLBACK),
            "steps_log": log_entries
        }

    async def node_hs_validation(self, state: WorkflowState):
        log_entries = await self._emit_log(state, "hs_validation", "running")
        agent = HSCodeValidationAgent(self.org_id)
        extracted = state["extracted"]
        
        hs_result = await agent.run({
            "items": extracted.get("items", []),
            "from_country": "IN",
            "to_country":   extracted.get("buyer_country", "AE")[:2].upper() if extracted.get("buyer_country") else "AE",
        })
        hs_data = hs_result["data"]
        risk_flags = [{"message": f, "severity": "high"} for f in hs_data.get("flags", [])]
        
        log_entries.extend(await self._emit_log(state, "hs_validation", "done", {
            "clearance": hs_data.get("overall_clearance"),
            "flags": len(risk_flags)
        }))
        
        return {
            "hs_data": hs_data,
            "risk_flags": risk_flags,
            "steps_log": log_entries
        }

    async def node_doc_generation(self, state: WorkflowState):
        log_entries = await self._emit_log(state, "doc_generation", "running")
        agent = DocumentGenerationAgent(self.org_id)
        extracted = state["extracted"]
        hs_data = state["hs_data"]
        
        order_data = {
            "buyer":    extracted.get("buyer_name"),
            "country":  extracted.get("buyer_country"),
            "items":    hs_data.get("validations", []),
            "currency": extracted.get("currency", "USD"),
            "terms":    extracted.get("payment_terms"),
            "incoterms": extracted.get("incoterms"),
            "port":     extracted.get("destination_port"),
        }

        invoice_result = await agent.run({"doc_type": "commercial_invoice", "order": order_data})
        packing_result = await agent.run({"doc_type": "packing_list",       "order": order_data})
        invoice_data = invoice_result["doc_data"]
        
        new_confidence = min(state["overall_confidence"], invoice_result.get("confidence", cfg.CONFIDENCE_DEFAULT_FALLBACK))
        
        log_entries.extend(await self._emit_log(state, "doc_generation", "done", {
            "docs": ["commercial_invoice", "packing_list"],
            "confidence": new_confidence
        }))
        
        return {
            "documents": {
                "commercial_invoice": invoice_data,
                "packing_list":       packing_result["doc_data"],
            },
            "overall_confidence": new_confidence,
            "steps_log": log_entries
        }

    async def node_hitl_evaluation(self, state: WorkflowState):
        log_entries = await self._emit_log(state, "hitl_evaluation", "running")
        
        hitl_decision = HITLOrchestrator.evaluate("doc_generation", state["overall_confidence"], state["risk_flags"])
        log_entries.extend(await self._emit_log(state, "hitl_evaluation", "done", hitl_decision))

        approval_required = hitl_decision["requires_human"]
        approval_id = str(uuid.uuid4()) if approval_required else None
        
        if approval_required:
            log_entries.extend(await self._emit_log(state, "awaiting_human", "paused", {
                "approval_id": approval_id,
                "decision":    hitl_decision["decision"],
                "reason":      hitl_decision["reason"],
                "confidence":  state["overall_confidence"],
            }))
            
        return {
            "hitl_decision": hitl_decision,
            "approval_id": approval_id,
            "status": "awaiting_approval" if approval_required else "completed",
            "steps_log": log_entries
        }

    def route_after_hitl(self, state: WorkflowState):
        if state["hitl_decision"].get("requires_human"):
            return "awaiting_approval"
        return "dispatch"

    async def node_dispatch(self, state: WorkflowState):
        log_entries = await self._emit_log(state, "dispatch", "running")
        
        if state.get("buyer_whatsapp"):
            invoice_data = state["documents"].get("commercial_invoice", {})
            await WhatsAppService.send_text(
                to=state["buyer_whatsapp"],
                body=(
                    f"✅ Your order has been confirmed and documents are ready.\n\n"
                    f"Order: {invoice_data.get('invoice_number', 'N/A')}\n"
                    f"Amount: {invoice_data.get('currency')} {invoice_data.get('grand_total')}\n"
                    f"Terms: {invoice_data.get('payment_terms')}\n"
                    f"ETA: 3 working days\n\n"
                    f"Documents will follow shortly. Thank you! 🚢"
                )
            )
        log_entries.extend(await self._emit_log(state, "dispatch", "done", {"channel": "whatsapp"}))
        return {"steps_log": log_entries}

    async def execute(
        self,
        source: str,
        raw_text: str | None = None,
        file_bytes: bytes | None = None,
        buyer_whatsapp: str | None = None,
        buyer_email: str | None = None,
    ) -> dict:
        
        initial_state = {
            "org_id": self.org_id,
            "source": source,
            "raw_text": raw_text,
            "file_bytes": file_bytes,
            "buyer_whatsapp": buyer_whatsapp,
            "buyer_email": buyer_email,
            "workflow_id": str(uuid.uuid4()),
            "steps_log": [],
            "extracted": {},
            "hs_data": {},
            "risk_flags": [],
            "overall_confidence": 100,
            "documents": {},
            "hitl_decision": {},
            "approval_id": None,
            "status": "running"
        }

        # Run the graph
        final_state = await self.app.ainvoke(initial_state)

        # Map back to the expected output format
        return {
            "workflow_id":       final_state["workflow_id"],
            "status":            final_state["status"],
            "approval_id":       final_state.get("approval_id"),
            "hitl_decision":     final_state.get("hitl_decision"),
            "overall_confidence": final_state.get("overall_confidence"),
            "steps":             final_state.get("steps_log", []),
            "extracted_order":   final_state.get("extracted"),
            "hs_validation":     final_state.get("hs_data"),
            "documents":         final_state.get("documents"),
            "risk_flags":        final_state.get("risk_flags"),
        }
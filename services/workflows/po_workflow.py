import uuid
from datetime import datetime
from services.agents.po_extraction import POExtractionAgent
from services.agents.hs_validation import HSCodeValidationAgent
from services.agents.doc_generation import DocumentGenerationAgent
from services.integrations.whatsapp import WhatsAppService
from services.api.main import DocumentIntelligenceEngine, HITLOrchestrator

class KillerDemoWorkflow:
    """The workflow that closes deals. Decoupled and distributed agent calling."""
    
    def __init__(self, org_id: uuid.UUID, db=None):
        self.org_id = org_id
        self.db = db

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
            doc_intel = await DocumentIntelligenceEngine.extract_from_file(file_bytes, "application/pdf")
            raw_text = doc_intel["raw_text"]

        extraction = await agent.run({"source": source, "raw_text": raw_text or ""})
        extracted = extraction["data"]
        log("po_extraction", "done", {"confidence": extracted.get("confidence"), "items": len(extracted.get("items", []))})

        # ── STEP 2: HS CODE VALIDATION ────────────────────
        log("hs_validation", "running")
        hs_agent = HSCodeValidationAgent(self.org_id)
        hs_result = await hs_agent.run({
            "items": extracted.get("items", []),
            "from_country": "IN",
            "to_country":   extracted.get("buyer_country", "AE")[:2].upper() if extracted.get("buyer_country") else "AE",
        })
        hs_data = hs_result["data"]
        risk_flags = [{"message": f, "severity": "high"} for f in hs_data.get("flags", [])]
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

        invoice_result = await doc_agent.run({"doc_type": "commercial_invoice", "order": order_data})
        packing_result = await doc_agent.run({"doc_type": "packing_list",       "order": order_data})
        invoice_data = invoice_result["doc_data"]
        overall_confidence = min(extracted.get("confidence", 80), invoice_result.get("confidence", 80))
        log("doc_generation", "done", {"docs": ["commercial_invoice", "packing_list"], "confidence": overall_confidence})

        # ── STEP 4: HITL DECISION ─────────────────────────
        log("hitl_evaluation", "running")
        hitl_decision = HITLOrchestrator.evaluate("doc_generation", overall_confidence, risk_flags)
        log("hitl_evaluation", "done", hitl_decision)

        approval_required = hitl_decision["requires_human"]
        approval_id = str(uuid.uuid4()) if approval_required else None

        # ── STEP 5: SEND NOTIFICATION ─────────────────────
        if approval_required:
            log("awaiting_human", "paused", {
                "approval_id": approval_id,
                "decision":    hitl_decision["decision"],
                "reason":      hitl_decision["reason"],
                "confidence":  overall_confidence,
            })
        else:
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
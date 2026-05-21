import json
import uuid
from services.agents.base import BaseAgent
from services.api.main import parse_llm_json  # Keep matching JSON fallback parser

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
        source = input_data["source"]       
        raw_text = input_data.get("raw_text", "")

        try:
            from core.prompt_registry import PromptRegistry
            prompt_rec = PromptRegistry.get("po_extraction_agent", "extract_purchase_order")
            system_prompt = prompt_rec.system_prompt
        except Exception:
            system_prompt = self.SYSTEM_PROMPT

        buyer_memories = []
        if input_data.get("buyer_contact_id"):
            buyer_memories = await self._recall(
                query="buyer purchase order patterns",
                memory_type="customer_preference",
            )

        memory_context = f"\nKnown buyer patterns: {json.dumps(buyer_memories)}" if buyer_memories else ""

        result = await self.llm.complete(
            system_prompt=system_prompt + memory_context,
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

        extracted = parse_llm_json(result["text"], "PO extraction")

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
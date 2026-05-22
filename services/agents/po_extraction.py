"""
TradeOS — PO Extraction Agent (services/agents/po_extraction.py)
=================================================================
Uses prompt_registry v4 schema — includes requires_clarification output.
All confidence thresholds read from .env via cfg.
"""

import json
import uuid
from services.agents.base import BaseAgent
from services.api.main import parse_llm_json
from core.config import cfg


class POExtractionAgent(BaseAgent):
    name = "po_extraction_agent"

    # Fallback system prompt if registry unavailable
    SYSTEM_PROMPT = """
You are an expert in international trade purchase orders.
Extract structured data from any PO format: PDF, WhatsApp message, email body, or scanned image.
Handle Arabic, English, Hindi. Normalize all values.
Output confidence score 0-100 overall. Flag ambiguous fields as warnings.
For missing mandatory fields, add them to requires_clarification with exact questions to ask the buyer.
Do not hallucinate values.
"""

    async def run(self, input_data: dict) -> dict:
        source   = input_data["source"]
        raw_text = input_data.get("raw_text", "")

        # Try to load versioned prompt from registry
        system_prompt  = self.SYSTEM_PROMPT
        output_schema  = self._default_schema()
        try:
            from core.prompt_registry import PromptRegistry
            prompt_rec    = PromptRegistry.get("po_extraction_agent", "extract_purchase_order")
            system_prompt = prompt_rec.system_prompt
            output_schema = prompt_rec.output_schema
        except Exception as exc:
            print(f"[POExtractionAgent] Registry fallback: {exc}")

        # Recall buyer patterns if contact known
        buyer_memories = []
        if input_data.get("buyer_contact_id"):
            buyer_memories = await self._recall(
                query="buyer purchase order patterns",
                memory_type="customer_preference",
            )
        memory_context = (
            f"\nKnown buyer patterns: {json.dumps(buyer_memories)}"
            if buyer_memories else ""
        )

        # Build user prompt with template variables
        user_prompt = (
            f"Source: {source}\n"
            f"Language detected: auto\n"
            f"Buyer history context: {json.dumps(buyer_memories) if buyer_memories else 'none'}\n\n"
            f"--- BEGIN PO CONTENT ---\n"
            f"{raw_text}\n"
            f"--- END PO CONTENT ---\n\n"
            f"Extract all fields. Compute confidence breakdown. "
            f"List missing mandatory fields in requires_clarification with exact buyer questions.\n"
            f"Return valid JSON only."
        ) + memory_context

        result = await self.llm.complete(
            system_prompt=system_prompt,
            user_prompt=user_prompt,
            output_schema=output_schema,
            temperature=0.0,
        )

        extracted = parse_llm_json(result["text"], "PO extraction")

        # Ensure requires_clarification is always a list
        if "requires_clarification" not in extracted:
            extracted["requires_clarification"] = []

        # Ensure confidence is a float
        raw_conf = extracted.get("confidence", cfg.CONFIDENCE_THRESHOLD_FALLBACK)
        extracted["confidence"] = float(raw_conf * 100 if float(raw_conf) <= 1.0 else raw_conf)

        # Learn buyer pattern
        await self._remember(
            key="last_po_pattern",
            value={"items": extracted.get("items", []), "currency": extracted.get("currency")},
            memory_type="customer_preference",
            scope_type="contact",
        )

        self._emit_event("po.extracted", {
            "org_id":              str(self.org_id),
            "confidence":          extracted.get("confidence"),
            "item_count":          len(extracted.get("items", [])),
            "clarifications_needed": len(extracted.get("requires_clarification", [])),
        })

        return {
            "status":   "ok",
            "data":     extracted,
            "provider": result.get("provider_used"),
        }

    @staticmethod
    def _default_schema() -> dict:
        """Minimal schema used when prompt registry is unavailable."""
        return {
            "buyer_name":             "string|null",
            "buyer_country":          "string|null",
            "buyer_address":          "string|null",
            "items": [{
                "description":        "string",
                "quantity":           0.0,
                "unit":               "string",
                "unit_price":         0.0,
                "hs_code":            "string|null",
                "hs_code_source":     "buyer_provided|ai_suggested|unknown",
                "hs_confidence":      0,
                "country_of_origin":  "string|null",
            }],
            "currency":               "string|null",
            "total_value":            0.0,
            "payment_terms":          "string|null",
            "incoterms":              "string|null",
            "destination_port":       "string|null",
            "destination_country":    "string|null",
            "delivery_date":          "string|null",
            "special_instructions":   "string|null",
            "confidence":             0,
            "confidence_breakdown": {
                "buyer_info":         0,
                "items":              0,
                "commercial_terms":   0,
                "logistics":          0,
            },
            "warnings":               ["string"],
            "requires_clarification": [
                {"field": "string", "question": "string", "blocking": True}
            ],
        }

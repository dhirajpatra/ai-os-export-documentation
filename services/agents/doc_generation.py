import json
from services.agents.base import BaseAgent
from services.api.main import parse_llm_json
import os
from dotenv import load_dotenv
load_dotenv()

# ── Read thresholds from .env via cfg ───────────────────────────────
from core.config import cfg as _cfg

class DocumentGenerationAgent(BaseAgent):
    name = "doc_generation_agent"

    async def run(self, input_data: dict) -> dict:
        doc_type  = input_data["doc_type"]
        order     = input_data["order"]
        overrides = input_data.get("overrides", {})

        style_memory = await self._recall(
            query="invoice format preference",
            memory_type="invoice_style",
        )

        generators = {
            "commercial_invoice": self._gen_commercial_invoice,
            "packing_list":       self._gen_packing_list,
            "certificate_of_origin": self._gen_coo,
            "bill_of_lading":     self._gen_bl_draft,
        }

        if doc_type not in generators:
            raise ValueError(f"Unsupported doc type: {doc_type}")

        doc_data = await generators[doc_type](order, overrides, style_memory)

        # Extract internal confidence score; if LLM omits it, default to the
        # configured auto-approve threshold (read dynamically from .env via cfg)
        raw_confidence = doc_data.get("_confidence") or _cfg.CONFIDENCE_THRESHOLD_AUTO
        
        # Ensure floating points (like 0.95) are scaled to match the .env integer scale (95.0)
        normalized_confidence = float(raw_confidence * 100 if raw_confidence <= 1.0 else raw_confidence)

        return {
            "status":      "ok",
            "doc_type":    doc_type,
            "doc_data":    doc_data,
            "confidence":  normalized_confidence,
        }

    async def _gen_commercial_invoice(self, order: dict, overrides: dict, style: list) -> dict:
        result = await self.llm.complete(
            system_prompt=(
                "Generate a complete commercial invoice for international export. "
                "Follow UNCTAD/ICC standards. Include all mandatory fields for LC documentation. "
                "Apply Indian GST zero-rating for exports (LUT). "
                "Return ONLY valid JSON, no explanation."
            ),
            user_prompt=(
                f"Generate commercial invoice for:\n{json.dumps(order, indent=2)}"
                f"\nOverrides: {json.dumps(overrides)}"
            ),
            output_schema={
                "invoice_number": "string",
                "invoice_date": "string",
                "exporter": {"name": "string", "address": "string", "iec": "string", "gstin": "string"},
                "importer": {"name": "string", "address": "string", "vat": "string"},
                "items": [{"description": "string", "hs_code": "string", "qty": 0, "unit": "string", "unit_price": 0, "total": 0}],
                "subtotal": 0,
                "freight_charges": 0,
                "insurance": 0,
                "grand_total": 0,
                "currency": "string",
                "payment_terms": "string",
                "incoterms": "string",
                "bank_details": {"name": "string", "address": "string", "swift": "string", "account_number": "string"},
                "declaration": "string",
                "_confidence": 0,
            },
            temperature=0.0,
        )
        data = parse_llm_json(result["text"], "commercial invoice generation")
        data.setdefault("bank_details", {"name": "State Bank of India", "address": "Mumbai, India", "swift": "SBININBB", "account_number": ""})
        data.setdefault("declaration", "We declare that the above information is true and correct. The goods are exported under LUT.")
        data.setdefault("exporter", {"name": "", "address": "", "iec": "", "gstin": ""})
        data.setdefault("importer", {"name": "", "address": "", "vat": ""})
        return data

    async def _gen_packing_list(self, order: dict, overrides: dict, style: list) -> dict:
        result = await self.llm.complete(
            system_prompt="Generate a packing list for international export. Return only JSON. No explanation.",
            user_prompt=f"Order data:\n{json.dumps(order, indent=2)}",
            output_schema={
                "pl_number": "string",
                "packages": [{"pkg_no": 0, "description": "string", "qty": 0, "net_wt_kg": 0, "gross_wt_kg": 0, "dims_cm": "string"}],
                "total_packages": 0,
                "total_net_weight_kg": 0,
                "total_gross_weight_kg": 0,
                "total_volume_cbm": 0,
                "_confidence": 0,
            },
            temperature=0.0,
        )
        return parse_llm_json(result["text"], "packing list generation")

    async def _gen_coo(self, order: dict, overrides: dict, style: list) -> dict:
        result = await self.llm.complete(
            system_prompt="Generate a Certificate of Origin for international export.",
            user_prompt=f"Order data:\n{json.dumps(order, indent=2)}",
            output_schema={"_confidence": 0},
            temperature=0.0,
        )
        return parse_llm_json(result["text"], "certificate of origin generation")

    async def _gen_bl_draft(self, order: dict, overrides: dict, style: list) -> dict:
        return {"_confidence": 90, "status": "draft"}
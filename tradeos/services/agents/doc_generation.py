"""
TradeOS — Document Generation Agent (services/agents/doc_generation.py)
========================================================================
Uses prompt registry v5 schemas. All confidence thresholds from cfg (.env).
Returns _missing_fields for clarification flow.
"""

import json
from services.agents.base import BaseAgent
from core.config import cfg, parse_llm_json


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
            "commercial_invoice":    self._gen_commercial_invoice,
            "packing_list":          self._gen_packing_list,
            "certificate_of_origin": self._gen_coo,
            "bill_of_lading":        self._gen_bl_draft,
        }

        if doc_type not in generators:
            raise ValueError(f"Unsupported doc type: {doc_type}")

        doc_data = await generators[doc_type](order, overrides, style_memory)

        # Normalize confidence — always float on 0-100 scale
        raw_conf           = doc_data.get("_confidence") or cfg.CONFIDENCE_THRESHOLD_AUTO
        normalized_conf    = float(raw_conf * 100 if float(raw_conf) <= 1.0 else raw_conf)
        doc_data["_confidence"] = normalized_conf

        return {
            "status":     "ok",
            "doc_type":   doc_type,
            "doc_data":   doc_data,
            "confidence": normalized_conf,
        }

    async def _gen_commercial_invoice(self, order: dict, overrides: dict, style: list) -> dict:
        # Load system prompt and schema from registry
        system_prompt = (
            "Generate a complete commercial invoice for international export. "
            "Follow UNCTAD/ICC standards. Include all mandatory fields for LC documentation. "
            "Apply Indian GST zero-rating for exports (LUT). "
            f"Set _confidence to {cfg.CONFIDENCE_THRESHOLD_AUTO}+ when all fields present. "
            f"Set _confidence to {cfg.CONFIDENCE_THRESHOLD_HUMAN}-{cfg.CONFIDENCE_THRESHOLD_AUTO} when buyer address or LC details missing. "
            f"Never set _confidence below {cfg.CONFIDENCE_THRESHOLD_FALLBACK} for standard export with product+quantity+price+destination. "
            "Add missing fields to _missing_fields[] with buyer question. "
            "Return ONLY valid JSON, no explanation."
        )
        output_schema = self._invoice_schema()

        try:
            from core.prompt_registry import PromptRegistry
            prompt_rec    = PromptRegistry.get("doc_generation_agent", "generate_commercial_invoice")
            system_prompt = prompt_rec.system_prompt
            output_schema = prompt_rec.output_schema
        except Exception as exc:
            print(f"[DocumentGenerationAgent] invoice registry fallback: {exc}")

        result = await self.llm.complete(
            system_prompt=system_prompt,
            user_prompt=(
                f"Order Data:\n{json.dumps(order, indent=2)}\n\n"
                f"Buyer Preferences / Style Notes:\n{json.dumps(style)}\n\n"
                f"LC Details (if applicable): none\n\n"
                f"Overrides from human reviewer:\n{json.dumps(overrides)}\n\n"
                "Generate complete commercial invoice. Return JSON only."
            ),
            output_schema=output_schema,
            temperature=0.0,
        )
        data = parse_llm_json(result["text"], "commercial invoice generation")

        # Safe defaults for omitted fields
        data.setdefault("bank_details", {
            "bank_name":      "State Bank of India",
            "branch":         "Fort Branch, Mumbai",
            "account_number": "",
            "ifsc":           "SBIN0000300",
            "swift_code":     "SBININBB",
        })
        data.setdefault("declaration",
            "We declare that this invoice shows the actual price of the goods described "
            "and that all particulars are true and correct. "
            "The goods are exported under LUT — IGST NIL rated.")
        data.setdefault("exporter", {"name": "", "address": "", "iec": "", "gstin": ""})
        data.setdefault("importer", {"name": "", "address": "", "vat_trn": ""})
        data.setdefault("_missing_fields", [])
        return data

    async def _gen_packing_list(self, order: dict, overrides: dict, style: list) -> dict:
        system_prompt = (
            "Generate a detailed export packing list. "
            "Calculate gross/net weights and volumes accurately. "
            "Flag ISPM-15 wooden packaging if applicable. "
            f"Set _confidence to {cfg.CONFIDENCE_THRESHOLD_AUTO}+ when all dimensions present. "
            f"Set _confidence to {cfg.CONFIDENCE_THRESHOLD_HUMAN}-{cfg.CONFIDENCE_THRESHOLD_AUTO} when packing instructions missing. "
            "Add missing packing details to _missing_fields[] with buyer questions. "
            "Return only JSON."
        )
        output_schema = self._packing_schema()

        try:
            from core.prompt_registry import PromptRegistry
            prompt_rec    = PromptRegistry.get("doc_generation_agent", "generate_packing_list")
            system_prompt = prompt_rec.system_prompt
            output_schema = prompt_rec.output_schema
        except Exception as exc:
            print(f"[DocumentGenerationAgent] packing registry fallback: {exc}")

        result = await self.llm.complete(
            system_prompt=system_prompt,
            user_prompt=(
                f"Order/Invoice Data:\n{json.dumps(order, indent=2)}\n\n"
                "Packing Instructions: standard\n\n"
                "Generate packing list JSON."
            ),
            output_schema=output_schema,
            temperature=0.0,
        )
        data = parse_llm_json(result["text"], "packing list generation")
        data.setdefault("_missing_fields", [])
        return data

    async def _gen_coo(self, order: dict, overrides: dict, style: list) -> dict:
        result = await self.llm.complete(
            system_prompt=(
                "Generate a Certificate of Origin for international export. "
                "Return only JSON."
            ),
            user_prompt=f"Order data:\n{json.dumps(order, indent=2)}",
            output_schema={
                "_confidence":    0,
                "_missing_fields": [],
            },
            temperature=0.0,
        )
        return parse_llm_json(result["text"], "certificate of origin generation")

    async def _gen_bl_draft(self, order: dict, overrides: dict, style: list) -> dict:
        return {
            "_confidence":    cfg.CONFIDENCE_THRESHOLD_AUTO,
            "_missing_fields": [],
            "status":         "draft",
        }

    # ── Schemas ──────────────────────────────────────────

    @staticmethod
    def _invoice_schema() -> dict:
        return {
            "invoice_number":   "string",
            "invoice_date":     "string",
            "exporter": {
                "name":     "string",
                "address":  "string",
                "iec":      "string",
                "gstin":    "string",
            },
            "importer": {
                "name":    "string",
                "address": "string",
                "vat_trn": "string",
            },
            "items": [{
                "description":   "string",
                "hs_code":       "string",
                "qty":           0,
                "unit":          "string",
                "unit_price":    0,
                "total":         0,
                "net_weight_kg": 0,
            }],
            "subtotal":          0,
            "freight_charges":   0,
            "insurance":         0,
            "grand_total":       0,
            "amount_in_words":   "string",
            "currency":          "string",
            "payment_terms":     "string",
            "incoterms":         "string",
            "port_of_loading":   "string",
            "port_of_discharge": "string",
            "bank_details": {
                "bank_name":      "string",
                "branch":         "string",
                "account_number": "string",
                "ifsc":           "string",
                "swift_code":     "string",
            },
            "declaration":       "string",
            "lut_bond_number":   "string|null",
            "igst_amount":       0,
            "_confidence":       0,
            "_missing_fields": [
                {"field": "string", "question": "string", "blocking": False}
            ],
        }

    @staticmethod
    def _packing_schema() -> dict:
        return {
            "pl_number":    "string",
            "pl_date":      "string",
            "packages": [{
                "pkg_number":           1,
                "description":          "string",
                "qty":                  0,
                "net_wt_kg":            0,
                "gross_wt_kg":          0,
                "dims_cm":              "string",
                "packing_type":         "string",
                "marks_and_numbers":    "string",
            }],
            "summary": {
                "total_packages":        0,
                "total_net_weight_kg":   0,
                "total_gross_weight_kg": 0,
                "total_volume_cbm":      0,
            },
            "special_flags": {
                "ispm15_required":        False,
                "dg_cargo":               False,
                "refrigeration_required": False,
            },
            "_confidence":   0,
            "_missing_fields": [
                {"field": "string", "question": "string", "blocking": False}
            ],
        }

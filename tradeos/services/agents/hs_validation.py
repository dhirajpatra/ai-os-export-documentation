"""
TradeOS — HS Code Validation Agent (services/agents/hs_validation.py)
======================================================================
All thresholds from cfg (.env). Uses prompt registry v3 schema.
Returns requires_clarification for unknown/missing HS codes.
"""

import json
from services.agents.base import BaseAgent
from core.config import cfg, parse_llm_json


class HSCodeValidationAgent(BaseAgent):
    name = "hs_validation_agent"

    SYSTEM_PROMPT = """
You are an international trade compliance expert specializing in HS codes.
Validate HS codes against WCO schedule, India ITC-HS, and UAE GCC tariff.
For each item: verify description match, check export policy, suggest corrections.
If HS code is missing or uncertain, add a clarification question to requires_clarification.
Score confidence based on match quality and route cleanliness.
"""

    async def run(self, input_data: dict) -> dict:
        items        = input_data["items"]
        from_country = input_data.get("from_country", "IN")
        to_country   = input_data.get("to_country",   "AE")

        # Load from prompt registry
        system_prompt = self.SYSTEM_PROMPT
        output_schema = self._default_schema()
        try:
            from core.prompt_registry import PromptRegistry
            prompt_rec    = PromptRegistry.get("hs_validation_agent", "validate_hs_codes")
            system_prompt = prompt_rec.system_prompt
            output_schema = prompt_rec.output_schema
        except Exception as exc:
            print(f"[HSCodeValidationAgent] Registry fallback: {exc}")

        cached_codes = await self._recall(
            query=" ".join(i.get("description", "") for i in items),
            memory_type="hs_code_learned",
        )

        result = await self.llm.complete(
            system_prompt=system_prompt,
            user_prompt=(
                f"Export Route: {from_country} → {to_country}\n"
                f"Incoterms: CIF\n\n"
                f"Items to validate:\n{json.dumps(items, indent=2)}\n\n"
                f"Previously validated codes for this exporter:\n{json.dumps(cached_codes)}\n\n"
                f"Validate each item. Flag missing info as clarification questions. Return JSON."
            ),
            output_schema=output_schema,
            temperature=0.0,
        )

        data = parse_llm_json(result["text"], "HS code validation")

        # Ensure all confidence values are float
        for v in data.get("validations", []):
            raw = v.get("confidence", cfg.CONFIDENCE_HS_CLOSE)
            v["confidence"] = float(raw * 100 if float(raw) <= 1.0 else raw)

            # Cache well-validated codes
            if v.get("is_valid") and v["confidence"] >= cfg.CONFIDENCE_HS_CLOSE:
                await self._remember(
                    key=v.get("validated_hs_code", ""),
                    value={
                        "description": v.get("original_description", ""),
                        "route":       f"{from_country}-{to_country}",
                    },
                    memory_type="hs_code_learned",
                    confidence=v["confidence"],
                )

        return {"status": "ok", "data": data}

    @staticmethod
    def _default_schema() -> dict:
        return {
            "validations": [{
                "original_description":   "string",
                "original_hs_code":       "string|null",
                "validated_hs_code":      "string",
                "is_valid":               True,
                "confidence":             0,
                "india_export_policy":    "Free|Restricted|Prohibited|Canalized|STE",
                "restrictions":           ["string"],
                "permits_required":       ["string"],
                "import_duty_pct":        0,
                "correction_reason":      "string",
                "severity":               "ok|warning|high|critical",
                "requires_clarification": [
                    {"field": "string", "question": "string", "blocking": False}
                ],
            }],
            "overall_clearance": True,
            "flags":             ["string"],
            "notes":             "string",
        }

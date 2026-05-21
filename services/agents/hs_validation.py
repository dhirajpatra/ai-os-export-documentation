import json
from services.agents.base import BaseAgent
from services.api.main import parse_llm_json

class HSCodeValidationAgent(BaseAgent):
    name = "hs_validation_agent"

    SYSTEM_PROMPT = """
You are an international trade compliance expert specializing in HS (Harmonized System) codes.
Validate HS codes against the official WCO schedule.
For each code: verify description match, check for country-specific restrictions,
flag prohibited/restricted categories, suggest corrections if wrong.
Consider both the 6-digit WCO code and country-specific extensions (8-digit for India, UAE).
"""

    async def run(self, input_data: dict) -> dict:
        items = input_data["items"]
        from_country = input_data.get("from_country", "IN")
        to_country = input_data.get("to_country", "AE")

        try:
            from core.prompt_registry import PromptRegistry
            prompt_rec = PromptRegistry.get("hs_validation_agent", "validate_hs_codes")
            system_prompt = prompt_rec.system_prompt
        except Exception:
            system_prompt = self.SYSTEM_PROMPT

        cached_codes = await self._recall(
            query=" ".join(i.get("description", "") for i in items),
            memory_type="hs_code_learned",
        )

        output_schema = {
            "validations": [{
                "original_description": "string",
                "original_hs_code":     "string",
                "validated_hs_code":    "string",
                "is_valid":             True,
                "confidence":           90,
                "correction_reason":    "string",
            }],
            "overall_clearance": True,
            "flags": [],
        }

        result = await self.llm.complete(
            system_prompt=system_prompt,
            user_prompt=(
                f"Validate these items for export from {from_country} to {to_country}:\n"
                f"{json.dumps(items, indent=2)}\n"
                f"Previously validated codes for this org: {json.dumps(cached_codes)}"
            ),
            output_schema=output_schema,
            temperature=0.0,
        )

        data = parse_llm_json(result["text"], "HS code validation")

        for v in data.get("validations", []):
            if v.get("is_valid") and v.get("confidence", 0) > 85:
                await self._remember(
                    key=v["validated_hs_code"],
                    value={"description": v["original_description"], "route": f"{from_country}-{to_country}"},
                    memory_type="hs_code_learned",
                    confidence=v["confidence"],
                )

        return {"status": "ok", "data": data}
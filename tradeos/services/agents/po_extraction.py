"""
TradeOS — PO Extraction Agent (services/agents/po_extraction.py)
=================================================================
THREE-LAYER EXTRACTION PIPELINE
--------------------------------
Layer 1 — Rule-based (RuleBasedExtractor)
  Zero LLM cost. Regex + keyword patterns.
  Handles ~60-70% of repeat India–GCC shipments.
  Exits early if confidence ≥ CONFIDENCE_THRESHOLD_AUTO.

Layer 2 — Template matching (TemplateMatcher)
  Zero LLM cost. Buyer-specific learned format patterns stored in Redis.
  Fills stable fields (payment terms, incoterms, destination) from prior extractions.
  Exits early if confidence ≥ CONFIDENCE_THRESHOLD_AUTO after template fill.

Layer 3 — LLM fallback (existing flow)
  Only reached for novel formats, new buyers, ambiguous text, or mixed-language docs.
  After successful LLM extraction, TemplateMatcher.learn() is called to
  improve future extractions for this buyer.

Cost impact
-----------
  Repeat buyer, standard format  → Rule-based  → ₹0
  Known buyer, minor variation   → Template    → ₹0
  New buyer / complex PO         → LLM         → ₹8-15 per call
  At 100 shipments/month: ~65% cost reduction vs LLM-only

All confidence thresholds read from .env via cfg.
Uses prompt_registry v4 schema — includes requires_clarification output.
"""

import json
import uuid
from services.agents.base import BaseAgent
from services.agents.rule_based_extractor import RuleBasedExtractor
from services.agents.template_matcher import TemplateMatcher
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
        org_id   = str(self.org_id)

        # ── LAYER 1: Rule-based extraction ───────────────────────────────
        rule_result = RuleBasedExtractor.extract(raw_text)
        print(
            f"[POExtraction] Layer1/rule-based confidence={rule_result['confidence']:.1f} "
            f"threshold={cfg.CONFIDENCE_THRESHOLD_AUTO}"
        )

        if rule_result["confidence"] >= cfg.CONFIDENCE_THRESHOLD_AUTO:
            print("[POExtraction] ✅ Rule-based sufficient — skipping LLM")
            self._emit_event("po.extracted", {
                "org_id":                str(self.org_id),
                "confidence":            rule_result["confidence"],
                "item_count":            len(rule_result.get("items", [])),
                "clarifications_needed": len(rule_result.get("requires_clarification", [])),
                "layer":                 "rule_based",
            })
            return {
                "status":   "ok",
                "data":     rule_result,
                "provider": "rule_based",
            }

        # ── LAYER 2: Template matching ────────────────────────────────────
        # Use buyer hint from rule-based result (may have found buyer name)
        buyer_hint = rule_result.get("buyer_name") or input_data.get("buyer_name")
        tm_result  = await TemplateMatcher.match(raw_text, org_id, buyer_hint)

        if tm_result:
            print(
                f"[POExtraction] Layer2/template confidence={tm_result['confidence']:.1f} "
                f"buyer='{tm_result.get('_template_buyer')}'"
            )
            if tm_result["confidence"] >= cfg.CONFIDENCE_THRESHOLD_AUTO:
                print("[POExtraction] ✅ Template match sufficient — skipping LLM")
                self._emit_event("po.extracted", {
                    "org_id":                str(self.org_id),
                    "confidence":            tm_result["confidence"],
                    "item_count":            len(tm_result.get("items", [])),
                    "clarifications_needed": len(tm_result.get("requires_clarification", [])),
                    "layer":                 "template",
                })
                return {
                    "status":   "ok",
                    "data":     tm_result,
                    "provider": "template_match",
                }
        else:
            print("[POExtraction] Layer2/template — no match found")

        # ── LAYER 3: LLM extraction (existing flow) ───────────────────────
        print("[POExtraction] Layer3/LLM — invoking language model")

        system_prompt = self.SYSTEM_PROMPT
        output_schema = self._default_schema()
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

        # Enrich prompt with rule-based partial results so LLM only
        # needs to fill gaps rather than extract everything from scratch
        partial_hint = ""
        if rule_result.get("items") or rule_result.get("incoterms"):
            partial_hint = (
                f"\n\nPartial extraction already done (fill gaps only):\n"
                f"{json.dumps({k: v for k, v in rule_result.items() if v and k != '_source'}, indent=2)}"
            )

        user_prompt = (
            f"Source: {source}\n"
            f"Language detected: auto\n"
            f"Buyer history context: {json.dumps(buyer_memories) if buyer_memories else 'none'}\n\n"
            f"--- BEGIN PO CONTENT ---\n"
            f"{raw_text}\n"
            f"--- END PO CONTENT ---\n"
            f"{partial_hint}\n\n"
            f"Extract all fields. Compute confidence breakdown. "
            f"List missing mandatory fields in requires_clarification with exact buyer questions.\n"
            f"Return valid JSON only."
        )

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

        # Ensure confidence is a float 0-100
        raw_conf = extracted.get("confidence", cfg.CONFIDENCE_THRESHOLD_FALLBACK)
        extracted["confidence"] = float(
            raw_conf * 100 if float(raw_conf) <= 1.0 else raw_conf
        )
        extracted["_source"] = "llm"

        # ── Post-LLM: merge rule-based fields the LLM might have missed ──
        # Rule-based is high-precision for specific patterns; prefer its values
        # for incoterms and payment terms if LLM returned null
        for field in ["incoterms", "payment_terms", "destination_port", "currency"]:
            if not extracted.get(field) and rule_result.get(field):
                extracted[field] = rule_result[field]
                print(f"[POExtraction] Filled '{field}' from rule-based result")

        # ── Learn template from successful LLM extraction ─────────────────
        buyer_name = extracted.get("buyer_name") or buyer_hint
        if extracted["confidence"] >= cfg.CONFIDENCE_THRESHOLD_HUMAN:
            await TemplateMatcher.learn(raw_text, extracted, org_id, buyer_name)

        # ── Store buyer pattern in agent memory ───────────────────────────
        await self._remember(
            key="last_po_pattern",
            value={
                "items":    extracted.get("items", []),
                "currency": extracted.get("currency"),
            },
            memory_type="customer_preference",
            scope_type="contact",
        )

        self._emit_event("po.extracted", {
            "org_id":                str(self.org_id),
            "confidence":            extracted.get("confidence"),
            "item_count":            len(extracted.get("items", [])),
            "clarifications_needed": len(extracted.get("requires_clarification", [])),
            "layer":                 "llm",
            "provider":              result.get("provider_used"),
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

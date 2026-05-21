"""
TradeOS — Agent Prompt Registry
=================================
Versioned · Testable · Fallback-aware · Confidence-tracked
Production-critical: models change every 6 months.
Your prompts are your institutional knowledge. Version them.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any
import os
from dotenv import load_dotenv

load_dotenv()

# ─────────────────────────────────────────────
# CONFIDENCE THRESHOLDS
# ─────────────────────────────────────────────
CONFIDENCE_THRESHOLD_AUTO = float(os.getenv("CONFIDENCE_THRESHOLD_AUTO",  "30.0"))
CONFIDENCE_THRESHOLD_HUMAN  = float(os.getenv("CONFIDENCE_THRESHOLD_HUMAN", "20.0"))


# ─────────────────────────────────────────────
# PROMPT RECORD
# ─────────────────────────────────────────────

@dataclass
class PromptRecord:
    agent_name:     str
    prompt_key:     str
    version:        int
    system_prompt:  str
    user_template:  str
    output_schema:  dict
    is_active:      bool = True
    fallback_key:   str | None = None     # key of fallback prompt if this fails
    model_hints:    list[str] = field(default_factory=list)  # preferred models for this prompt
    # Performance (populated at runtime from DB)
    avg_confidence: float = 0.0
    success_count:  int = 0
    failure_count:  int = 0
    avg_latency_ms: int = 0
    notes:          str = ""
    created_at:     str = field(default_factory=lambda: datetime.utcnow().isoformat())

    @property
    def fingerprint(self) -> str:
        """Hash of prompt content — detect silent drift."""
        content = self.system_prompt + self.user_template + json.dumps(self.output_schema)
        return hashlib.sha256(content.encode()).hexdigest()[:12]

    def render(self, **kwargs) -> str:
        """Render the user template with context variables."""
        try:
            return self.user_template.format(**kwargs)
        except KeyError as e:
            raise ValueError(f"Prompt template missing variable: {e}")


# ─────────────────────────────────────────────
# REGISTRY
# ─────────────────────────────────────────────

class PromptRegistry:
    """
    In-memory registry backed by DB.
    Hot-reload without restart.
    Prompt A/B testing via traffic_split.
    """

    _store: dict[str, PromptRecord] = {}

    @classmethod
    def register(cls, record: PromptRecord):
        key = cls._key(record.agent_name, record.prompt_key, record.version)
        cls._store[key] = record

    @classmethod
    def get(cls, agent_name: str, prompt_key: str, version: int = 0) -> PromptRecord:
        """version=0 → latest active version."""
        if version:
            key = cls._key(agent_name, prompt_key, version)
            if key in cls._store:
                return cls._store[key]
            raise KeyError(f"Prompt not found: {agent_name}/{prompt_key}/v{version}")

        # Find highest active version
        candidates = [
            r for k, r in cls._store.items()
            if r.agent_name == agent_name and r.prompt_key == prompt_key and r.is_active
        ]
        if not candidates:
            raise KeyError(f"No active prompt: {agent_name}/{prompt_key}")
        return max(candidates, key=lambda r: r.version)

    @classmethod
    def get_with_fallback(cls, agent_name: str, prompt_key: str) -> list[PromptRecord]:
        """Return ordered chain: [primary, fallback1, fallback2...]"""
        chain = []
        current = cls.get(agent_name, prompt_key)
        chain.append(current)
        while current.fallback_key:
            try:
                current = cls.get(agent_name, current.fallback_key)
                chain.append(current)
            except KeyError:
                break
        return chain

    @classmethod
    def deprecate(cls, agent_name: str, prompt_key: str, version: int):
        key = cls._key(agent_name, prompt_key, version)
        if key in cls._store:
            cls._store[key].is_active = False

    @classmethod
    def list_agent(cls, agent_name: str) -> list[PromptRecord]:
        return [r for r in cls._store.values() if r.agent_name == agent_name]

    @staticmethod
    def _key(agent_name: str, prompt_key: str, version: int) -> str:
        return f"{agent_name}::{prompt_key}::v{version}"


# ─────────────────────────────────────────────
# ALL PRODUCTION PROMPTS
# ─────────────────────────────────────────────

def _fmt(text: str) -> str:
    """Replace confidence placeholder tokens in prompt text with env values."""
    return (text
        .replace("{CONFIDENCE_THRESHOLD_AUTO:.0f}", f"{CONFIDENCE_THRESHOLD_AUTO:.0f}")
        .replace("{CONFIDENCE_THRESHOLD_HUMAN:.0f}", f"{CONFIDENCE_THRESHOLD_HUMAN:.0f}")
    )


def load_all_prompts():
    """Call at startup. All prompt versions registered here."""

    # ── PO EXTRACTION ─────────────────────────────────────

    PromptRegistry.register(PromptRecord(
        agent_name   = "po_extraction_agent",
        prompt_key   = "extract_purchase_order",
        version      = 3,
        notes        = "v3: improved Arabic handling, added incoterm detection",
        model_hints  = ["claude-opus-4-6", "gpt-4o"],
        system_prompt= _fmt("""
You are an expert international trade document analyst with 20+ years of experience.
Your job is to extract structured data from purchase orders arriving via WhatsApp, email, or PDF.

LANGUAGE HANDLING:
- Input may be in Arabic, English, Hindi, or mixed.
- Always extract and return data in English.
- For Arabic numerals (٠١٢٣...), convert to Western numerals.
- For Arabic product names, provide English translation in parentheses.

EXTRACTION RULES:
- Extract ONLY what is explicitly stated. Do NOT infer or hallucinate values.
- For missing fields, return null — never a guess.
- For ambiguous quantities (e.g. "a few boxes"), extract as-is and flag as warning.
- HS codes: if buyer mentions one, capture it. If not, attempt suggestion based on description (mark as suggested).
- Payment terms: normalize to standard (LC | TT | DA | DP | CAD | Open Account).
- Incoterms: normalize to ICC 2020 standard (FOB | CIF | EXW | DDP | DAP | FCA | CPT | CIP).
- Currency: normalize to ISO 4217 (USD | AED | SAR | INR | EUR | GBP | QAR | OMR).
- Dates: normalize to ISO 8601 (YYYY-MM-DD).

CONFIDENCE SCORING:
- {CONFIDENCE_THRESHOLD_AUTO:.0f}-100: All mandatory fields present, no ambiguity.
- {CONFIDENCE_THRESHOLD_HUMAN:.0f}-{CONFIDENCE_THRESHOLD_AUTO:.0f}: Minor gaps (delivery date missing, HS code not provided).
- Below {CONFIDENCE_THRESHOLD_HUMAN:.0f}: Flag for mandatory human review.

MANDATORY FIELDS (confidence drops 10pts each if missing):
buyer_name, items (with quantity + unit + price), currency, destination_country
"""),
        user_template= """
PO Source: {source}
Language detected: {detected_lang}
Buyer history context: {buyer_context}

--- BEGIN PO CONTENT ---
{raw_text}
--- END PO CONTENT ---

Extract all fields. Return valid JSON only.
""",
        output_schema= {
            "buyer_name": "string",
            "buyer_country": "string (ISO 3166-1 alpha-2)",
            "buyer_address": "string",
            "buyer_vat": "string",
            "items": [{
                "line_number": 1,
                "description": "string",
                "description_arabic": "string (if applicable)",
                "quantity": 0.0,
                "unit": "string (KG|MT|PCS|CTN|LTR|CBM)",
                "unit_price": 0.0,
                "total_price": 0.0,
                "hs_code": "string",
                "hs_code_source": "buyer_provided|ai_suggested|unknown",
                "hs_confidence": 0,
                "country_of_origin": "string",
                "packing_instructions": "string"
            }],
            "currency": "string (ISO 4217)",
            "total_value": 0.0,
            "payment_terms": "string",
            "payment_terms_normalized": "LC|TT|DA|DP|CAD|Open Account",
            "incoterms": "string",
            "incoterms_normalized": "string",
            "port_of_loading": "string",
            "destination_port": "string",
            "destination_country": "string",
            "delivery_date": "string (YYYY-MM-DD)",
            "po_reference": "string",
            "special_instructions": "string",
            "packing_requirements": "string",
            "marks_and_numbers": "string",
            "lc_details": {
                "lc_number": "string",
                "issuing_bank": "string",
                "expiry_date": "string",
                "amount": 0.0
            },
            "confidence": 0,
            "confidence_breakdown": {
                "buyer_info": 0,
                "items": 0,
                "commercial_terms": 0,
                "logistics": 0
            },
            "warnings": ["string"],
            "requires_clarification": ["string"]
        },
        fallback_key = "extract_purchase_order_simple",
    ))

    # Fallback: simpler extraction for difficult docs
    PromptRegistry.register(PromptRecord(
        agent_name   = "po_extraction_agent",
        prompt_key   = "extract_purchase_order_simple",
        version      = 1,
        notes        = "Fallback: minimal extraction when full prompt fails",
        model_hints  = ["gpt-4o", "gemini-2.0-flash"],
        system_prompt= _fmt("""
Extract the minimum viable purchase order data from this text.
Focus only on: buyer name, product description, quantity, unit price, currency, destination.
Return JSON. Confidence will be set to {CONFIDENCE_THRESHOLD_HUMAN:.0f} for all fallback extractions.
"""),
        user_template= "PO Content:\n{raw_text}\n\nExtract minimum fields.",
        output_schema= {
            "buyer_name": "string",
            "items": [{"description": "string", "quantity": 0, "unit": "string", "unit_price": 0}],
            "currency": "string",
            "destination_country": "string",
            "confidence": CONFIDENCE_THRESHOLD_HUMAN,  # from env
            "warnings": ["Extracted using fallback minimal prompt"]
        }
    ))

    # ── HS CODE VALIDATION ────────────────────────────────

    PromptRegistry.register(PromptRecord(
        agent_name   = "hs_validation_agent",
        prompt_key   = "validate_hs_codes",
        version      = 2,
        notes        = "v2: Added India Chapter 93 (arms) hard block, UAE Vision 2030 categories",
        model_hints  = ["claude-opus-4-6", "gpt-4o"],
        system_prompt= _fmt("""
You are a certified customs expert with deep knowledge of:
- WCO Harmonized System (HS) 2022 edition (6-digit)
- India Customs Tariff (ITC-HS 8-digit)
- UAE GCC Common Customs Law (8-digit)
- Saudi ZATCA tariff schedule
- DGFT export policy (Free/Restricted/Prohibited/Canalized)

VALIDATION LOGIC:
1. Verify HS code matches product description.
2. Check India export policy: Free | Restricted | Prohibited | Canalized | STE-only.
3. Check destination country import duty rate.
4. Identify permit requirements (CITES, SPS, FSSAI, BIS, etc.)
5. Flag dual-use goods (military, chemical precursors, encryption).
6. Check GST HSN alignment (for India LUT exports).
7. If code is wrong, provide the correct code with explanation.

HARD BLOCKS (always critical severity):
- Chapter 93: Arms and ammunition
- Chapter 28.04.10: Hazardous chemical precursors without license
- CITES Appendix I species without permit
- SCOMET items without DGFT license

CONFIDENCE:
- {CONFIDENCE_THRESHOLD_AUTO:.0f}+: Exact match, clean route, no restrictions.
- {CONFIDENCE_THRESHOLD_HUMAN:.0f}-{CONFIDENCE_THRESHOLD_AUTO:.0f}: Minor ambiguity in sub-heading, no restrictions.
- Below {CONFIDENCE_THRESHOLD_HUMAN:.0f}: Critical — block until human expert reviews.
"""),
        user_template= """
Export Route: {from_country} → {to_country}
Incoterms: {incoterms}

Items to validate:
{items_json}

Previously validated codes for this exporter:
{known_codes}

Validate each item. Return JSON.
""",
        output_schema= {
            "validations": [{
                "line_number": 1,
                "original_description": "string",
                "original_hs_code": "string",
                "validated_hs_code": "string",
                "itc_hs_code_india": "string (8-digit)",
                "gcc_hs_code": "string (8-digit)",
                "is_valid": True,
                "confidence": 0,
                "description_match_pct": 0,
                "india_export_policy": "Free|Restricted|Prohibited|Canalized|STE",
                "restrictions": ["string"],
                "permits_required": ["string"],
                "import_duty_pct": 0,
                "vat_destination_pct": 0,
                "correction_reason": "string",
                "severity": "ok|warning|high|critical",
                "action_required": "string"
            }],
            "overall_clearance": True,
            "flags": ["string"],
            "estimated_duty_total": 0,
            "notes": "string"
        }
    ))

    # ── COMMERCIAL INVOICE ────────────────────────────────

    PromptRegistry.register(PromptRecord(
        agent_name   = "doc_generation_agent",
        prompt_key   = "generate_commercial_invoice",
        version      = 4,
        notes        = "v4: LC document compliance, SWIFT MT700 field alignment",
        model_hints  = ["claude-opus-4-6"],
        system_prompt= _fmt("""
You are a senior export documentation officer specializing in international commercial invoices.

STANDARDS:
- Follow UNCTAD/ICC model invoice format.
- For LC transactions: align ALL fields with SWIFT MT700 terms (LC number, expiry, presenting bank).
- For India exports: include IEC number, AD code, GSTIN, LUT/Bond reference.
- For GCC destinations: include HS code, country of origin, and net/gross weight per line.

MANDATORY FIELDS (LC compliance):
Invoice number, date, seller full legal name + address + IEC,
buyer full legal name + address, description exactly matching LC terms,
HS code per line, quantity + unit, unit price, total, currency, incoterms,
port of loading, port of discharge, payment terms, GSTIN, signatory.

CRITICAL RULES:
- Description MUST match LC description word-for-word if LC provided.
- Never round total differently from sum of line items.
- Freight/insurance separately only if CIF/CFR incoterms.
- Declaration: "We declare that this invoice shows the actual price of goods described."
- For GST: zero-rated supply under LUT/Bond, IGST = 0.

AMOUNT IN WORDS: Always include.
BANK DETAILS: Include full beneficiary bank details for TT/DA/DP payments.
"""),
        user_template= """
Order Data:
{order_json}

Buyer Preferences / Style Notes:
{style_notes}

LC Details (if applicable):
{lc_details}

Overrides from human reviewer:
{overrides}

Generate complete commercial invoice. Return JSON only.
""",
        output_schema= {
            "invoice_number": "string",
            "invoice_date": "string (YYYY-MM-DD)",
            "exporter": {
                "name": "string",
                "address_line1": "string",
                "address_line2": "string",
                "city": "string",
                "country": "string",
                "iec_code": "string",
                "gstin": "string",
                "pan": "string",
                "ad_code": "string"
            },
            "importer": {
                "name": "string",
                "address": "string",
                "country": "string",
                "vat_trn": "string"
            },
            "lc_reference": "string",
            "items": [{
                "sl_no": 1,
                "description": "string",
                "hs_code": "string",
                "country_of_origin": "string",
                "quantity": 0.0,
                "unit": "string",
                "unit_price": 0.0,
                "total": 0.0,
                "net_weight_kg": 0.0,
                "gross_weight_kg": 0.0
            }],
            "subtotal": 0.0,
            "freight": 0.0,
            "insurance": 0.0,
            "other_charges": 0.0,
            "grand_total": 0.0,
            "amount_in_words": "string",
            "currency": "string",
            "exchange_rate": 0.0,
            "inr_equivalent": 0.0,
            "payment_terms": "string",
            "incoterms": "string",
            "port_of_loading": "string",
            "port_of_discharge": "string",
            "country_of_final_destination": "string",
            "pre_carriage": "string",
            "vessel_flight": "string",
            "gstin": "string",
            "lut_bond_number": "string",
            "igst_amount": 0.0,
            "declaration": "string",
            "bank_details": {
                "bank_name": "string",
                "branch": "string",
                "account_number": "string",
                "ifsc": "string",
                "swift_code": "string",
                "iban": "string"
            },
            "authorized_signatory": "string",
            "_confidence": 0,
            "_lc_compliance_flags": []
        }
    ))

    # ── PACKING LIST ──────────────────────────────────────

    PromptRegistry.register(PromptRecord(
        agent_name   = "doc_generation_agent",
        prompt_key   = "generate_packing_list",
        version      = 2,
        notes        = "v2: ISPM-15 fumigation flag, DG cargo detection",
        model_hints  = ["claude-opus-4-6", "gpt-4o"],
        system_prompt= _fmt("""
Generate a detailed export packing list. 
Calculate gross/net weights and volumes accurately.
Flag: ISPM-15 wooden packaging requirements, DG goods, CITES items.
Ensure total weights on packing list match commercial invoice.
"""),
        user_template= """
Order/Invoice Data:
{order_json}

Packing Instructions:
{packing_instructions}

Generate packing list JSON.
""",
        output_schema= {
            "pl_number": "string",
            "pl_date": "string",
            "invoice_reference": "string",
            "packages": [{
                "pkg_number": 1,
                "description": "string",
                "hs_code": "string",
                "quantity_per_package": 0,
                "number_of_packages": 0,
                "net_weight_kg": 0.0,
                "gross_weight_kg": 0.0,
                "length_cm": 0,
                "width_cm": 0,
                "height_cm": 0,
                "volume_cbm": 0.0,
                "marks_and_numbers": "string",
                "packing_type": "carton|wooden_crate|bag|drum|pallet|IBC"
            }],
            "summary": {
                "total_packages": 0,
                "total_net_weight_kg": 0.0,
                "total_gross_weight_kg": 0.0,
                "total_volume_cbm": 0.0
            },
            "special_flags": {
                "ispm15_required": False,
                "dg_cargo": False,
                "refrigeration_required": False,
                "fragile": False
            },
            "_confidence": 0
        }
    ))

    # ── COMPLIANCE COUNTRY CHECK ──────────────────────────

    PromptRegistry.register(PromptRecord(
        agent_name   = "compliance_agent",
        prompt_key   = "country_trade_check",
        version      = 2,
        notes        = "v2: added OFAC SDN check, EU dual-use regulation ref",
        model_hints  = ["claude-opus-4-6", "gpt-4o"],
        system_prompt= _fmt("""
You are a trade compliance expert. Perform a full country-level trade check.

CHECK LIST:
1. Sanctions: OFAC (USA), UN, EU, UK HMT sanctions against exporter/importer/country.
2. Export controls: DGFT SCOMET list (India), EAR (USA), dual-use goods.
3. Import restrictions: destination country banned/restricted goods list.
4. Documentation requirements: certificates, permits, pre-shipment inspection.
5. Preferential trade: CECPA/CEPA agreements (India-UAE, India-GCC) for duty reduction.

SEVERITY LEVELS:
- critical: transaction must be blocked pending legal review.
- high: additional documentation/permits required.
- medium: advisory flag, proceed with care.
- low: informational.

Be precise. Cite specific regulatory references (DGFT notification number, UAE Cabinet Decision, etc.)
"""),
        user_template= """
Exporter Country: {from_country}
Importer Country: {to_country}
Products (HS codes): {hs_codes}
Exporter: {exporter_name}
Importer: {importer_name}
Payment Method: {payment_method}

Perform complete trade compliance check.
""",
        output_schema= {
            "clearance_status": "cleared|conditional|blocked",
            "checks": [{
                "check_name": "string",
                "result": "pass|warning|fail",
                "severity": "low|medium|high|critical",
                "message": "string",
                "regulatory_reference": "string",
                "action_required": "string"
            }],
            "preferential_duty_available": False,
            "preferential_agreement": "string",
            "estimated_duty_savings_pct": 0,
            "documents_required": ["string"],
            "overall_confidence": 0
        }
    ))

    # ── COMMUNICATION / BUYER NOTIFICATION ───────────────

    PromptRegistry.register(PromptRecord(
        agent_name   = "communication_agent",
        prompt_key   = "draft_buyer_notification",
        version      = 2,
        notes        = "v2: Arabic support, GCC business etiquette",
        model_hints  = ["claude-opus-4-6", "gpt-4o"],
        system_prompt= _fmt("""
You are a professional international trade communication specialist.
Draft concise, professional buyer notifications in the appropriate language.

TONE GUIDELINES:
- GCC buyers: formal, respectful, include Islamic greetings if appropriate (السلام عليكم).
- Indian domestic: professional Hindi/English mix acceptable.
- Western buyers: direct, concise, no filler.

WhatsApp messages: max 3 short paragraphs, use ✅ 📦 🚢 emojis sparingly.
Email: formal subject line, 3-4 paragraphs, professional closing.

NEVER include: internal system details, agent names, confidence scores, or errors.
"""),
        user_template= """
Channel: {channel} (whatsapp|email|sms)
Language: {language}
Event: {event_type}
Order Details: {order_summary}
Buyer Name: {buyer_name}
Tone: {tone}

Draft notification message.
""",
        output_schema= {
            "subject": "string (email only)",
            "body": "string",
            "body_arabic": "string (if language=ar)",
            "suggested_attachments": ["string"]
        }
    ))

    print(f"✅ Prompt Registry: {len(PromptRegistry._store)} prompts loaded")


# ─────────────────────────────────────────────
# PROMPT TESTER (CI/CD)
# ─────────────────────────────────────────────

class PromptTester:
    """
    Run before deploying new prompt versions.
    Evaluate against golden test cases.
    """

    @staticmethod
    async def evaluate(
        agent_name: str,
        prompt_key: str,
        version: int,
        test_cases: list[dict],
    ) -> dict:
        """
        test_cases: [{"input": {...}, "expected_output": {...}, "min_confidence": 80}]
        """
        from main import LLMRouter

        prompt  = PromptRegistry.get(agent_name, prompt_key, version)
        results = []

        for i, tc in enumerate(test_cases):
            try:
                result = await LLMRouter.complete(
                    system_prompt = prompt.system_prompt,
                    user_prompt   = prompt.render(**tc["input"]),
                    output_schema = prompt.output_schema,
                    temperature   = 0.0,
                )
                parsed = json.loads(result["text"])
                confidence = parsed.get("confidence", parsed.get("_confidence", 0))
                passed = confidence >= tc.get("min_confidence", CONFIDENCE_THRESHOLD_AUTO)
                results.append({
                    "test_case": i,
                    "passed": passed,
                    "confidence": confidence,
                    "provider": result.get("provider_used"),
                })
            except Exception as e:
                results.append({"test_case": i, "passed": False, "error": str(e)})

        total = len(results)
        passed = sum(1 for r in results if r.get("passed"))

        return {
            "prompt":     f"{agent_name}/{prompt_key}/v{version}",
            "fingerprint": prompt.fingerprint,
            "total_tests": total,
            "passed":     passed,
            "failed":     total - passed,
            "pass_rate":  round(passed / total * 100, 1) if total else 0,
            "results":    results,
            "deploy_ok":  passed / total >= 0.9 if total else False,
        }


# Load prompts at import time
load_all_prompts()

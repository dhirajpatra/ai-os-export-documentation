"""
TradeOS — Agent Prompt Registry
=================================
Versioned · Testable · Fallback-aware · Confidence-tracked
All thresholds driven by .env — zero hardcoded scores.
Missing-field clarification: agents ask buyer via WhatsApp before processing.
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
# ALL THRESHOLDS FROM .env — NO HARDCODED VALUES
# ─────────────────────────────────────────────
CONFIDENCE_THRESHOLD_AUTO           = float(os.getenv("CONFIDENCE_THRESHOLD_AUTO",           "85.0"))
CONFIDENCE_THRESHOLD_HUMAN          = float(os.getenv("CONFIDENCE_THRESHOLD_HUMAN",           "70.0"))
CONFIDENCE_THRESHOLD_FALLBACK       = float(os.getenv("CONFIDENCE_THRESHOLD_FALLBACK",        "75.0"))
CONFIDENCE_THRESHOLD_BLOCK          = float(os.getenv("CONFIDENCE_THRESHOLD_BLOCK",           "50.0"))
CONFIDENCE_PENALTY_MISSING_FIELD    = float(os.getenv("CONFIDENCE_PENALTY_MISSING_FIELD",     "5.0"))
CONFIDENCE_PENALTY_MISSING_CRITICAL = float(os.getenv("CONFIDENCE_PENALTY_MISSING_CRITICAL",  "15.0"))
CONFIDENCE_FLOOR_WHATSAPP           = float(os.getenv("CONFIDENCE_FLOOR_WHATSAPP",            "80.0"))
CONFIDENCE_FLOOR_PARTIAL            = float(os.getenv("CONFIDENCE_FLOOR_PARTIAL",             "70.0"))
CONFIDENCE_FLOOR_MINIMAL            = float(os.getenv("CONFIDENCE_FLOOR_MINIMAL",             "60.0"))
CONFIDENCE_HS_EXACT                 = float(os.getenv("CONFIDENCE_HS_EXACT",                  "90.0"))
CONFIDENCE_HS_CLOSE                 = float(os.getenv("CONFIDENCE_HS_CLOSE",                  "75.0"))
CONFIDENCE_HS_BLOCK                 = float(os.getenv("CONFIDENCE_HS_BLOCK",                  "50.0"))
PROMPT_TEST_PASS_RATE_THRESHOLD     = float(os.getenv("PROMPT_TEST_PASS_RATE_THRESHOLD",      "0.9"))

# ─────────────────────────────────────────────
# MISSING FIELD DEFINITIONS — drives clarification questions
# ─────────────────────────────────────────────
# Fields that BLOCK processing until provided by buyer
CRITICAL_FIELDS = os.getenv(
    "CRITICAL_FIELDS",
    "items,currency,destination_country"
).split(",")

# Fields that trigger a WhatsApp clarification question (non-blocking)
CLARIFICATION_FIELDS = os.getenv(
    "CLARIFICATION_FIELDS",
    "buyer_name,unit_price,payment_terms,incoterms,delivery_date"
).split(",")

# Clarification question templates per field
CLARIFICATION_QUESTIONS: dict[str, str] = {
    "buyer_name":      "Could you please share your company name for the invoice?",
    "unit_price":      "What is the unit price per {unit} in {currency}?",
    "payment_terms":   "What are your preferred payment terms? (e.g. LC at sight, TT, DA 30 days)",
    "incoterms":       "Which Incoterms apply? (e.g. CIF, FOB, EXW)",
    "delivery_date":   "What is your required delivery / shipment date?",
    "destination_port":"Which port or city should we ship to?",
    "buyer_address":   "Could you share your delivery address or company address?",
    "lc_details":      "Will you be opening an LC? If yes, please share LC number and issuing bank.",
    "hs_code":         "Do you have an HS code for {description}? If not, we will suggest one.",
    "packing_instructions": "Any specific packing requirements? (e.g. bag size, labelling language)",
}


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
    fallback_key:   str | None = None
    model_hints:    list[str] = field(default_factory=list)
    avg_confidence: float = 0.0
    success_count:  int = 0
    failure_count:  int = 0
    avg_latency_ms: int = 0
    notes:          str = ""
    created_at:     str = field(default_factory=lambda: datetime.utcnow().isoformat())

    @property
    def fingerprint(self) -> str:
        content = self.system_prompt + self.user_template + json.dumps(self.output_schema)
        return hashlib.sha256(content.encode()).hexdigest()[:12]

    def render(self, **kwargs) -> str:
        try:
            return self.user_template.format(**kwargs)
        except KeyError as e:
            raise ValueError(f"Prompt template missing variable: {e}")


# ─────────────────────────────────────────────
# REGISTRY
# ─────────────────────────────────────────────

class PromptRegistry:
    _store: dict[str, PromptRecord] = {}

    @classmethod
    def register(cls, record: PromptRecord):
        key = cls._key(record.agent_name, record.prompt_key, record.version)
        cls._store[key] = record

    @classmethod
    def get(cls, agent_name: str, prompt_key: str, version: int = 0) -> PromptRecord:
        if version:
            key = cls._key(agent_name, prompt_key, version)
            if key in cls._store:
                return cls._store[key]
            raise KeyError(f"Prompt not found: {agent_name}/{prompt_key}/v{version}")
        candidates = [
            r for k, r in cls._store.items()
            if r.agent_name == agent_name and r.prompt_key == prompt_key and r.is_active
        ]
        if not candidates:
            raise KeyError(f"No active prompt: {agent_name}/{prompt_key}")
        return max(candidates, key=lambda r: r.version)

    @classmethod
    def get_with_fallback(cls, agent_name: str, prompt_key: str) -> list[PromptRecord]:
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
# CLARIFICATION ENGINE
# Determines missing fields and generates buyer questions
# Used by LangGraph orchestration before triggering full workflow
# ─────────────────────────────────────────────

class ClarificationEngine:
    """
    Inspects extracted PO data and determines:
    1. BLOCKING fields — cannot process without these
    2. CLARIFICATION fields — ask buyer, but can proceed with lower confidence
    3. Questions to send to buyer via WhatsApp
    """

    @staticmethod
    def check(extracted: dict, source: str = "whatsapp") -> dict:
        """
        Returns:
            blocked: bool — True if critical fields missing
            blocking_fields: list — fields that must be provided
            clarification_fields: list — fields to ask buyer
            questions: list[str] — WhatsApp messages to send buyer
            can_proceed: bool — True if workflow can start (even with clarifications pending)
        """
        items = extracted.get("items", [])
        blocking   = []
        clarify    = []
        questions  = []

        # Check critical blocking fields
        if not items or len(items) == 0:
            blocking.append("items")
            questions.append("What products would you like to order? Please share product name, quantity, and unit (e.g. 1000 KG Basmati Rice Grade A).")

        if not extracted.get("currency"):
            blocking.append("currency")
            questions.append("What currency should the invoice be in? (e.g. USD, AED, EUR)")

        if not extracted.get("destination_country") and not extracted.get("destination_port"):
            blocking.append("destination_country")
            questions.append("What is the destination country or port for this shipment?")

        # Check items for missing prices
        for item in items:
            if not item.get("unit_price") or item.get("unit_price") == 0:
                clarify.append("unit_price")
                desc = item.get("description", "the product")
                unit = item.get("unit", "unit")
                currency = extracted.get("currency", "USD")
                questions.append(f"What is the unit price per {unit} for {desc}? (in {currency})")
                break  # ask once, not per item

        # Check clarification fields (non-blocking for WhatsApp source)
        if source == "whatsapp":
            # WhatsApp orders naturally skip these — only ask if truly needed
            if not extracted.get("payment_terms"):
                clarify.append("payment_terms")
                questions.append(CLARIFICATION_QUESTIONS["payment_terms"])

            if not extracted.get("incoterms"):
                clarify.append("incoterms")
                questions.append(CLARIFICATION_QUESTIONS["incoterms"])
        else:
            # For PDF/email — ask for all clarification fields
            for f in CLARIFICATION_FIELDS:
                if not extracted.get(f):
                    clarify.append(f)
                    if f in CLARIFICATION_QUESTIONS:
                        questions.append(CLARIFICATION_QUESTIONS[f])

        blocked     = len(blocking) > 0
        can_proceed = not blocked

        return {
            "blocked":            blocked,
            "can_proceed":        can_proceed,
            "blocking_fields":    blocking,
            "clarification_fields": clarify,
            "questions":          questions,
            "question_count":     len(questions),
        }

    @staticmethod
    def build_whatsapp_question(missing_fields: list[str], extracted: dict) -> str:
        """Build a single consolidated WhatsApp message asking for missing info."""
        if not missing_fields:
            return ""

        lines = ["To process your order, could you please confirm a few details:\n"]
        for i, field_name in enumerate(missing_fields[:5], 1):  # max 5 questions
            q = CLARIFICATION_QUESTIONS.get(field_name, f"Please provide: {field_name}")
            # Render any placeholders in the question
            try:
                q = q.format(
                    unit=extracted.get("items", [{}])[0].get("unit", "unit") if extracted.get("items") else "unit",
                    currency=extracted.get("currency", "USD"),
                    description=extracted.get("items", [{}])[0].get("description", "the product") if extracted.get("items") else "the product",
                )
            except (KeyError, IndexError):
                pass
            lines.append(f"{i}. {q}")

        lines.append("\nOnce confirmed, we'll generate your documents right away. 📦")
        return "\n".join(lines)


# ─────────────────────────────────────────────
# _fmt helper — renders env threshold tokens in prompt strings
# ─────────────────────────────────────────────

def _fmt(text: str) -> str:
    """Replace all threshold tokens with live env values."""
    replacements = {
        "{CONFIDENCE_THRESHOLD_AUTO}":           f"{CONFIDENCE_THRESHOLD_AUTO:.0f}",
        "{CONFIDENCE_THRESHOLD_HUMAN}":          f"{CONFIDENCE_THRESHOLD_HUMAN:.0f}",
        "{CONFIDENCE_THRESHOLD_FALLBACK}":       f"{CONFIDENCE_THRESHOLD_FALLBACK:.0f}",
        "{CONFIDENCE_THRESHOLD_BLOCK}":          f"{CONFIDENCE_THRESHOLD_BLOCK:.0f}",
        "{CONFIDENCE_FLOOR_WHATSAPP}":           f"{CONFIDENCE_FLOOR_WHATSAPP:.0f}",
        "{CONFIDENCE_FLOOR_PARTIAL}":            f"{CONFIDENCE_FLOOR_PARTIAL:.0f}",
        "{CONFIDENCE_FLOOR_MINIMAL}":            f"{CONFIDENCE_FLOOR_MINIMAL:.0f}",
        "{CONFIDENCE_HS_EXACT}":                 f"{CONFIDENCE_HS_EXACT:.0f}",
        "{CONFIDENCE_HS_CLOSE}":                 f"{CONFIDENCE_HS_CLOSE:.0f}",
        "{CONFIDENCE_HS_BLOCK}":                 f"{CONFIDENCE_HS_BLOCK:.0f}",
        "{CONFIDENCE_PENALTY_MISSING_FIELD}":    f"{CONFIDENCE_PENALTY_MISSING_FIELD:.0f}",
        "{CONFIDENCE_PENALTY_MISSING_CRITICAL}": f"{CONFIDENCE_PENALTY_MISSING_CRITICAL:.0f}",
        "{CRITICAL_FIELDS}":                     ", ".join(CRITICAL_FIELDS),
        "{CLARIFICATION_FIELDS}":                ", ".join(CLARIFICATION_FIELDS),
    }
    for token, value in replacements.items():
        text = text.replace(token, value)
    return text


# ─────────────────────────────────────────────
# ALL PRODUCTION PROMPTS
# ─────────────────────────────────────────────

def load_all_prompts():
    """Call at startup. All prompt versions registered here."""

    # ── PO EXTRACTION ─────────────────────────────────────

    PromptRegistry.register(PromptRecord(
        agent_name   = "po_extraction_agent",
        prompt_key   = "extract_purchase_order",
        version      = 4,
        notes        = "v4: source-aware confidence, clarification-first, all thresholds from env",
        model_hints  = ["claude-sonnet-4-6", "gpt-4o", "groq/llama-3.3-70b"],
        system_prompt= _fmt("""
You are an expert international trade document analyst with 20+ years of experience.
Extract structured data from purchase orders arriving via WhatsApp, email, or PDF.

LANGUAGE HANDLING:
- Input may be in Arabic, English, Hindi, or mixed.
- Always extract and return data in English.
- Arabic numerals (٠١٢٣...): convert to Western numerals.
- Arabic product names: provide English translation in parentheses.

EXTRACTION RULES:
- Extract ONLY what is explicitly stated. Do NOT infer or hallucinate values.
- For missing fields, return null — never a guess.
- Flag ambiguous values in warnings[].
- HS codes: capture if buyer provides. Suggest from description if not (mark hs_code_source=ai_suggested).
- Payment terms: normalize to LC | TT | DA | DP | CAD | Open Account.
- Incoterms: normalize to FOB | CIF | EXW | DDP | DAP | FCA | CPT | CIP.
- Currency: normalize to ISO 4217 (USD | AED | SAR | INR | EUR | GBP).
- Dates: normalize to ISO 8601 (YYYY-MM-DD).

CONFIDENCE SCORING — all thresholds from configuration:
Auto-approval threshold: {CONFIDENCE_THRESHOLD_AUTO}
Human review threshold:  {CONFIDENCE_THRESHOLD_HUMAN}
Fallback minimum:        {CONFIDENCE_THRESHOLD_FALLBACK}
Hard block threshold:    {CONFIDENCE_THRESHOLD_BLOCK}

SCORING BY SOURCE TYPE:

For WhatsApp / informal messages (source=whatsapp):
- Score {CONFIDENCE_THRESHOLD_AUTO}+  when: product + quantity + unit + price + destination are all present.
- Score {CONFIDENCE_FLOOR_WHATSAPP}-{CONFIDENCE_THRESHOLD_AUTO} when: price OR destination missing but product+quantity clear.
- Score {CONFIDENCE_FLOOR_PARTIAL}-{CONFIDENCE_FLOOR_WHATSAPP} when: quantity unclear OR multiple ambiguities.
- Score {CONFIDENCE_THRESHOLD_BLOCK}-{CONFIDENCE_FLOOR_PARTIAL} when: only product name present, nothing else.
- Score below {CONFIDENCE_THRESHOLD_BLOCK}: ONLY when message has zero extractable order data.
- WhatsApp NEVER penalizes for missing buyer_name, delivery_date, or lc_details.
- Deduct {CONFIDENCE_PENALTY_MISSING_FIELD} per missing clarification field: {CLARIFICATION_FIELDS}.
- Deduct {CONFIDENCE_PENALTY_MISSING_CRITICAL} per missing critical field: {CRITICAL_FIELDS}.

For formal PDF / email (source=file|email):
- Score {CONFIDENCE_THRESHOLD_AUTO}+  when: all mandatory fields present, no ambiguity.
- Score {CONFIDENCE_THRESHOLD_HUMAN}-{CONFIDENCE_THRESHOLD_AUTO} when: minor gaps (no delivery date, no HS code).
- Score {CONFIDENCE_THRESHOLD_BLOCK}-{CONFIDENCE_THRESHOLD_HUMAN} when: multiple unclear fields.
- Score below {CONFIDENCE_THRESHOLD_BLOCK}: block — mandatory human review.
- Deduct {CONFIDENCE_PENALTY_MISSING_FIELD} per missing field.
- Deduct {CONFIDENCE_PENALTY_MISSING_CRITICAL} per missing critical field: {CRITICAL_FIELDS}.

CONFIDENCE BREAKDOWN — score each dimension 0-100:
- buyer_info:        buyer_name, buyer_country, buyer_address, buyer_vat
- items:             description, quantity, unit, unit_price, hs_code clarity
- commercial_terms:  currency, payment_terms, incoterms, total_value
- logistics:         destination_port, delivery_date, packing_requirements

Final confidence = weighted average:
  items(40%) + commercial_terms(30%) + logistics(20%) + buyer_info(10%)
Apply floor: WhatsApp minimum = {CONFIDENCE_FLOOR_WHATSAPP}, partial = {CONFIDENCE_FLOOR_PARTIAL}.

MISSING FIELDS ACTION:
- If critical fields missing ({CRITICAL_FIELDS}): set requires_clarification with specific questions.
- If clarification fields missing ({CLARIFICATION_FIELDS}): add to requires_clarification.
- The orchestrator will ask the buyer these questions before triggering document generation.
"""),
        user_template="""
PO Source: {source}
Language detected: {detected_lang}
Buyer history context: {buyer_context}

--- BEGIN PO CONTENT ---
{raw_text}
--- END PO CONTENT ---

Extract all fields. Compute confidence breakdown. List any missing fields in requires_clarification.
Return valid JSON only.
""",
        output_schema={
            "buyer_name":     "string|null",
            "buyer_country":  "string (ISO 3166-1 alpha-2)|null",
            "buyer_address":  "string|null",
            "buyer_vat":      "string|null",
            "items": [{
                "line_number":          1,
                "description":          "string",
                "description_arabic":   "string|null",
                "quantity":             0.0,
                "unit":                 "string (KG|MT|PCS|CTN|LTR|CBM)",
                "unit_price":           0.0,
                "total_price":          0.0,
                "hs_code":              "string|null",
                "hs_code_source":       "buyer_provided|ai_suggested|unknown",
                "hs_confidence":        0,
                "country_of_origin":    "string|null",
                "packing_instructions": "string|null",
            }],
            "currency":                    "string (ISO 4217)|null",
            "total_value":                 0.0,
            "payment_terms":               "string|null",
            "payment_terms_normalized":    "LC|TT|DA|DP|CAD|Open Account|null",
            "incoterms":                   "string|null",
            "incoterms_normalized":        "string|null",
            "port_of_loading":             "string|null",
            "destination_port":            "string|null",
            "destination_country":         "string|null",
            "delivery_date":               "string (YYYY-MM-DD)|null",
            "po_reference":                "string|null",
            "special_instructions":        "string|null",
            "packing_requirements":        "string|null",
            "marks_and_numbers":           "string|null",
            "lc_details": {
                "lc_number":    "string|null",
                "issuing_bank": "string|null",
                "expiry_date":  "string|null",
                "amount":       0.0,
            },
            "confidence": 0,
            "confidence_breakdown": {
                "buyer_info":        0,
                "items":             0,
                "commercial_terms":  0,
                "logistics":         0,
            },
            "warnings":               ["string"],
            "requires_clarification": [
                {
                    "field":    "string",
                    "question": "string (exact WhatsApp message to ask buyer)",
                    "blocking": True,
                }
            ],
        },
        fallback_key="extract_purchase_order_simple",
    ))

    # Fallback: minimal extraction
    PromptRegistry.register(PromptRecord(
        agent_name   = "po_extraction_agent",
        prompt_key   = "extract_purchase_order_simple",
        version      = 1,
        notes        = "Fallback: minimal extraction. Confidence floored at CONFIDENCE_THRESHOLD_FALLBACK.",
        model_hints  = ["gpt-4o", "gemini-2.5-flash-preview-04-17"],
        system_prompt= _fmt("""
Extract the minimum viable purchase order data.
Focus on: product description, quantity, unit, unit_price, currency, destination.
If buyer_name, delivery_date or lc_details are absent — that is normal, do not penalize.
Set confidence to {CONFIDENCE_THRESHOLD_FALLBACK} when product+quantity+destination are clear.
Set confidence to {CONFIDENCE_FLOOR_PARTIAL} when only product+quantity are clear.
Set confidence to {CONFIDENCE_FLOOR_MINIMAL} when only product name is available.
List all missing fields in requires_clarification with exact questions to ask the buyer.
Return JSON only.
"""),
        user_template="PO Content:\n{raw_text}\n\nExtract minimum fields. List missing fields as clarification questions.",
        output_schema={
            "buyer_name":   "string|null",
            "items": [{"description": "string", "quantity": 0.0, "unit": "string", "unit_price": 0.0}],
            "currency":             "string|null",
            "destination_country":  "string|null",
            "payment_terms":        "string|null",
            "incoterms":            "string|null",
            "confidence":           CONFIDENCE_THRESHOLD_FALLBACK,
            "warnings":             ["Extracted using fallback minimal prompt"],
            "requires_clarification": [
                {"field": "string", "question": "string", "blocking": True}
            ],
        }
    ))

    # ── HS CODE VALIDATION ────────────────────────────────

    PromptRegistry.register(PromptRecord(
        agent_name   = "hs_validation_agent",
        prompt_key   = "validate_hs_codes",
        version      = 3,
        notes        = "v3: env-driven confidence, food/agri fast-path, clarification questions",
        model_hints  = ["claude-sonnet-4-6", "gpt-4o"],
        system_prompt= _fmt("""
You are a certified customs expert with deep knowledge of:
- WCO Harmonized System (HS) 2022 (6-digit)
- India Customs Tariff ITC-HS (8-digit)
- UAE GCC Common Customs Law (8-digit)
- Saudi ZATCA tariff schedule
- DGFT export policy: Free | Restricted | Prohibited | Canalized | STE

VALIDATION LOGIC:
1. Verify HS code matches product description.
2. Check India export policy for each item.
3. Check destination country import duty rate.
4. Identify permits: CITES, SPS, FSSAI, BIS, APEDA, AGMARK.
5. Flag dual-use goods (military, chemical precursors, encryption tech).
6. Check GST HSN alignment for India LUT zero-rated exports.
7. If code is wrong, provide correct code with explanation.

HARD BLOCKS — always critical, score below {CONFIDENCE_HS_BLOCK}:
- Chapter 93: Arms and ammunition
- Chapter 28.04.10: Hazardous chemical precursors without license
- CITES Appendix I species without permit
- SCOMET items without DGFT license

FAST-PATH (common clean routes — score {CONFIDENCE_HS_EXACT}+):
- Basmati/non-Basmati Rice India→UAE/GCC: Chapter 10, free export, 5% UAE duty.
- Spices India→GCC (Chapter 09): free export, FSSAI + Phyto certificate needed.
- Edible oils India→UAE (Chapter 15): FSSAI, Halal cert needed.
- Textiles India→UAE (Chapters 50-63): free export, CoO needed.
- Pharmaceuticals (Chapter 30): CDSCO export NOC required.

CONFIDENCE SCORING — all values from configuration:
- {CONFIDENCE_HS_EXACT}+:            HS code exact match, clean route, no restrictions.
- {CONFIDENCE_HS_CLOSE}-{CONFIDENCE_HS_EXACT}: HS code matches at 6-digit, minor sub-heading uncertainty.
- {CONFIDENCE_THRESHOLD_BLOCK}-{CONFIDENCE_HS_CLOSE}: Code needs correction, product identifiable and exportable.
- Below {CONFIDENCE_THRESHOLD_BLOCK}: HARD BLOCKS only — arms, SCOMET, CITES.

Penalty per missing permit/certificate: -{CONFIDENCE_PENALTY_MISSING_FIELD} points.
If HS code missing entirely and product unidentifiable: add to clarification questions.
"""),
        user_template="""
Export Route: {from_country} → {to_country}
Incoterms: {incoterms}

Items to validate:
{items_json}

Previously validated codes for this exporter:
{known_codes}

Validate each item. Flag any missing info as clarification questions. Return JSON.
""",
        output_schema={
            "validations": [{
                "line_number":            1,
                "original_description":   "string",
                "original_hs_code":       "string|null",
                "validated_hs_code":      "string",
                "itc_hs_code_india":      "string (8-digit)",
                "gcc_hs_code":            "string (8-digit)",
                "is_valid":               True,
                "confidence":             0,
                "description_match_pct":  0,
                "india_export_policy":    "Free|Restricted|Prohibited|Canalized|STE",
                "restrictions":           ["string"],
                "permits_required":       ["string"],
                "import_duty_pct":        0,
                "vat_destination_pct":    0,
                "correction_reason":      "string",
                "severity":               "ok|warning|high|critical",
                "action_required":        "string",
                "requires_clarification": [
                    {"field": "string", "question": "string", "blocking": False}
                ],
            }],
            "overall_clearance":      True,
            "flags":                  ["string"],
            "estimated_duty_total":   0,
            "notes":                  "string",
        }
    ))

    # ── COMMERCIAL INVOICE ────────────────────────────────

    PromptRegistry.register(PromptRecord(
        agent_name   = "doc_generation_agent",
        prompt_key   = "generate_commercial_invoice",
        version      = 5,
        notes        = "v5: env confidence, LC compliance, clarification flags",
        model_hints  = ["claude-sonnet-4-6", "gpt-4o"],
        system_prompt= _fmt("""
You are a senior export documentation officer specializing in international commercial invoices.

STANDARDS:
- Follow UNCTAD/ICC model invoice format.
- For LC: align ALL fields with SWIFT MT700 (LC number, expiry, presenting bank).
- For India exports: IEC number, AD code, GSTIN, LUT/Bond reference.
- For GCC: HS code, country of origin, net/gross weight per line.

MANDATORY FIELDS (LC compliance):
Invoice number, date, seller full legal name + address + IEC,
buyer full legal name + address, description matching LC terms,
HS code per line, quantity + unit, unit price, total, currency, incoterms,
port of loading, port of discharge, payment terms, GSTIN, signatory.

CRITICAL RULES:
- Description MUST match LC description word-for-word if LC provided.
- Never round total differently from sum of line items.
- Freight/insurance separately only if CIF/CFR incoterms.
- Declaration: "We declare that this invoice shows the actual price of goods described."
- GST: zero-rated supply under LUT/Bond, IGST = 0.
- AMOUNT IN WORDS: Always include.
- BANK DETAILS: Always include for TT/DA/DP payments.

CONFIDENCE SCORING:
- Set _confidence = {CONFIDENCE_THRESHOLD_AUTO}+ when all mandatory fields are present and values are complete.
- Set _confidence = {CONFIDENCE_THRESHOLD_HUMAN}-{CONFIDENCE_THRESHOLD_AUTO} when buyer_address or lc_details are missing.
- Set _confidence = {CONFIDENCE_THRESHOLD_FALLBACK}-{CONFIDENCE_THRESHOLD_HUMAN} when multiple key fields missing.
- Never set _confidence below {CONFIDENCE_THRESHOLD_FALLBACK} for a standard export with product+quantity+price+destination.
- Add any missing fields to _missing_fields[] with the question to ask the buyer.
"""),
        user_template="""
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
        output_schema={
            "invoice_number":   "string",
            "invoice_date":     "string (YYYY-MM-DD)",
            "exporter": {
                "name":         "string",
                "address_line1":"string",
                "address_line2":"string",
                "city":         "string",
                "country":      "string",
                "iec_code":     "string",
                "gstin":        "string",
                "pan":          "string",
                "ad_code":      "string",
            },
            "importer": {
                "name":         "string",
                "address":      "string",
                "country":      "string",
                "vat_trn":      "string",
            },
            "lc_reference":     "string|null",
            "items": [{
                "sl_no":            1,
                "description":      "string",
                "hs_code":          "string",
                "country_of_origin":"string",
                "quantity":         0.0,
                "unit":             "string",
                "unit_price":       0.0,
                "total":            0.0,
                "net_weight_kg":    0.0,
                "gross_weight_kg":  0.0,
            }],
            "subtotal":                     0.0,
            "freight":                      0.0,
            "insurance":                    0.0,
            "other_charges":                0.0,
            "grand_total":                  0.0,
            "amount_in_words":              "string",
            "currency":                     "string",
            "exchange_rate":                0.0,
            "inr_equivalent":               0.0,
            "payment_terms":                "string",
            "incoterms":                    "string",
            "port_of_loading":              "string",
            "port_of_discharge":            "string",
            "country_of_final_destination": "string",
            "pre_carriage":                 "string",
            "vessel_flight":                "string|null",
            "gstin":                        "string",
            "lut_bond_number":              "string|null",
            "igst_amount":                  0.0,
            "declaration":                  "string",
            "bank_details": {
                "bank_name":        "string",
                "branch":           "string",
                "account_number":   "string",
                "ifsc":             "string",
                "swift_code":       "string",
                "iban":             "string|null",
            },
            "authorized_signatory":  "string",
            "_confidence":           0,
            "_lc_compliance_flags":  ["string"],
            "_missing_fields": [
                {"field": "string", "question": "string", "blocking": False}
            ],
        }
    ))

    # ── PACKING LIST ──────────────────────────────────────

    PromptRegistry.register(PromptRecord(
        agent_name   = "doc_generation_agent",
        prompt_key   = "generate_packing_list",
        version      = 3,
        notes        = "v3: env confidence, ISPM-15, DG detection, clarification flags",
        model_hints  = ["claude-sonnet-4-6", "gpt-4o"],
        system_prompt= _fmt("""
Generate a detailed export packing list.
Calculate gross/net weights and volumes accurately.
Flag: ISPM-15 wooden packaging, DG goods, CITES items, refrigeration.
Ensure total weights match the commercial invoice.

CONFIDENCE SCORING:
- Set _confidence = {CONFIDENCE_THRESHOLD_AUTO}+ when all dimensions, weights, and package counts are complete.
- Set _confidence = {CONFIDENCE_THRESHOLD_HUMAN}-{CONFIDENCE_THRESHOLD_AUTO} when packing instructions are missing but product data is clear.
- Add missing packing details to _missing_fields[] with buyer questions.
"""),
        user_template="""
Order/Invoice Data:
{order_json}

Packing Instructions:
{packing_instructions}

Generate packing list JSON.
""",
        output_schema={
            "pl_number":        "string",
            "pl_date":          "string",
            "invoice_reference":"string",
            "packages": [{
                "pkg_number":           1,
                "description":          "string",
                "hs_code":              "string",
                "quantity_per_package": 0,
                "number_of_packages":   0,
                "net_weight_kg":        0.0,
                "gross_weight_kg":      0.0,
                "length_cm":            0,
                "width_cm":             0,
                "height_cm":            0,
                "volume_cbm":           0.0,
                "marks_and_numbers":    "string",
                "packing_type":         "carton|wooden_crate|bag|drum|pallet|IBC",
            }],
            "summary": {
                "total_packages":       0,
                "total_net_weight_kg":  0.0,
                "total_gross_weight_kg":0.0,
                "total_volume_cbm":     0.0,
            },
            "special_flags": {
                "ispm15_required":          False,
                "dg_cargo":                 False,
                "refrigeration_required":   False,
                "fragile":                  False,
            },
            "_confidence":  0,
            "_missing_fields": [
                {"field": "string", "question": "string", "blocking": False}
            ],
        }
    ))

    # ── COMPLIANCE / COUNTRY CHECK ────────────────────────

    PromptRegistry.register(PromptRecord(
        agent_name   = "compliance_agent",
        prompt_key   = "country_trade_check",
        version      = 2,
        notes        = "v2: OFAC SDN, EU dual-use, CEPA duty savings",
        model_hints  = ["claude-sonnet-4-6", "gpt-4o"],
        system_prompt= _fmt("""
You are a trade compliance expert. Perform a full country-level trade check.

CHECK LIST:
1. Sanctions: OFAC (USA), UN, EU, UK HMT sanctions against exporter/importer/country.
2. Export controls: DGFT SCOMET list (India), EAR (USA), dual-use goods.
3. Import restrictions: destination country banned/restricted goods list.
4. Documentation requirements: certificates, permits, pre-shipment inspection.
5. Preferential trade: CECPA/CEPA agreements (India-UAE, India-GCC) for duty reduction.

SEVERITY:
- critical: block transaction pending legal review.
- high: additional documentation/permits required.
- medium: advisory, proceed with care.
- low: informational.

If critical information (HS codes, party names) is missing, add clarification questions.
Cite specific regulatory references (DGFT notification, UAE Cabinet Decision number).
"""),
        user_template="""
Exporter Country: {from_country}
Importer Country: {to_country}
Products (HS codes): {hs_codes}
Exporter: {exporter_name}
Importer: {importer_name}
Payment Method: {payment_method}

Perform complete trade compliance check. Return JSON.
""",
        output_schema={
            "clearance_status":             "cleared|conditional|blocked",
            "checks": [{
                "check_name":           "string",
                "result":               "pass|warning|fail",
                "severity":             "low|medium|high|critical",
                "message":              "string",
                "regulatory_reference": "string",
                "action_required":      "string",
            }],
            "preferential_duty_available":  False,
            "preferential_agreement":       "string",
            "estimated_duty_savings_pct":   0,
            "documents_required":           ["string"],
            "overall_confidence":           0,
            "requires_clarification": [
                {"field": "string", "question": "string", "blocking": False}
            ],
        }
    ))

    # ── BUYER NOTIFICATION / COMMUNICATION ────────────────

    PromptRegistry.register(PromptRecord(
        agent_name   = "communication_agent",
        prompt_key   = "draft_buyer_notification",
        version      = 2,
        notes        = "v2: Arabic support, GCC etiquette, clarification questions",
        model_hints  = ["claude-sonnet-4-6", "gpt-4o"],
        system_prompt= _fmt("""
You are a professional international trade communication specialist.
Draft concise, professional buyer notifications in the appropriate language.

TONE:
- GCC buyers: formal, respectful (السلام عليكم if appropriate).
- Indian: professional Hindi/English mix acceptable.
- Western: direct, concise, no filler.

WhatsApp: max 3 short paragraphs, ✅ 📦 🚢 emojis sparingly.
Email: formal subject line, 3-4 paragraphs, professional closing.

NEVER include: internal system details, agent names, confidence scores, errors.

For CLARIFICATION events: list each missing field as a numbered question.
Keep tone friendly. End with "Once confirmed, we'll process your order immediately."
"""),
        user_template="""
Channel: {channel} (whatsapp|email|sms)
Language: {language}
Event: {event_type}
Order Details: {order_summary}
Buyer Name: {buyer_name}
Tone: {tone}
Missing Fields (to ask): {missing_fields}

Draft notification message.
""",
        output_schema={
            "subject":              "string (email only)",
            "body":                 "string",
            "body_arabic":          "string|null",
            "suggested_attachments":["string"],
        }
    ))

    print(f"✅ Prompt Registry: {len(PromptRegistry._store)} prompts loaded")
    print(f"   Thresholds — AUTO:{CONFIDENCE_THRESHOLD_AUTO} HUMAN:{CONFIDENCE_THRESHOLD_HUMAN} "
          f"FLOOR_WA:{CONFIDENCE_FLOOR_WHATSAPP} HS_EXACT:{CONFIDENCE_HS_EXACT}")


# ─────────────────────────────────────────────
# PROMPT TESTER (CI/CD)
# ─────────────────────────────────────────────

class PromptTester:
    @staticmethod
    async def evaluate(
        agent_name: str,
        prompt_key: str,
        version: int,
        test_cases: list[dict],
    ) -> dict:
        from core.config import LLMRouter
        prompt  = PromptRegistry.get(agent_name, prompt_key, version)
        results = []
        for i, tc in enumerate(test_cases):
            try:
                result = await LLMRouter.complete(
                    system_prompt=prompt.system_prompt,
                    user_prompt  =prompt.render(**tc["input"]),
                    output_schema=prompt.output_schema,
                    temperature  =0.0,
                )
                parsed     = json.loads(result["text"])
                confidence = parsed.get("confidence", parsed.get("_confidence", 0))
                passed     = confidence >= tc.get("min_confidence", CONFIDENCE_THRESHOLD_AUTO)
                results.append({
                    "test_case": i,
                    "passed":    passed,
                    "confidence":confidence,
                    "provider":  result.get("provider_used"),
                })
            except Exception as e:
                results.append({"test_case": i, "passed": False, "error": str(e)})

        total  = len(results)
        passed = sum(1 for r in results if r.get("passed"))
        return {
            "prompt":      f"{agent_name}/{prompt_key}/v{version}",
            "fingerprint": prompt.fingerprint,
            "total_tests": total,
            "passed":      passed,
            "failed":      total - passed,
            "pass_rate":   round(passed / total * 100, 1) if total else 0,
            "results":     results,
            "deploy_ok":   passed / total >= PROMPT_TEST_PASS_RATE_THRESHOLD if total else False,
        }


# Load prompts at import time
load_all_prompts()

"""
services/agents/rule_based_extractor.py
=========================================
Layer 1 of the three-layer extraction pipeline.

Extracts structured PO fields using regex + keyword rules.
Zero LLM cost. Returns the same schema as POExtractionAgent._default_schema()
so po_extraction.py can use it as a direct drop-in.

Coverage
--------
  ✅ Quantities + units (kg, mt, ton, bags, pieces, cartons, litres)
  ✅ Incoterms (CIF, FOB, CFR, EXW, DDP, DAP, FCA, CPT)
  ✅ Payment terms (LC, TT, CAD, DA, DP, OA, advance)
  ✅ Currency (USD, EUR, GBP, AED, INR, SAR, QAR, OMR, KWD)
  ✅ Destination port → country mapping (India–GCC corridor focused)
  ✅ HS code (6/8 digit, with or without dots)
  ✅ Unit price patterns
  ✅ Total value patterns
  ✅ Delivery date (ISO, written, relative)
  ✅ Buyer name (From:/Buyer:/To: header patterns)
  ✅ Common India–GCC export commodities
  ✅ Confidence scoring per field
  ✅ requires_clarification populated for missing blocking fields
  ✅ Per-org commodity/HS overrides via org_overrides dict
"""

from __future__ import annotations

import re
from datetime import datetime, timedelta
from typing import Optional


# ─────────────────────────────────────────────────────────────────────────────
# PORT → COUNTRY MAP  (India–GCC corridor + common global ports)
# ─────────────────────────────────────────────────────────────────────────────

PORT_COUNTRY: dict[str, str] = {
    # UAE
    "jebel ali": "AE", "dubai": "AE", "abu dhabi": "AE",
    "sharjah": "AE", "fujairah": "AE", "khalifa": "AE",
    # Saudi Arabia
    "jeddah": "SA", "dammam": "SA", "riyadh": "SA",
    "king abdulaziz": "SA", "jubail": "SA",
    # Qatar
    "doha": "QA", "hamad": "QA",
    # Kuwait
    "kuwait": "KW", "shuwaikh": "KW", "shuaiba": "KW",
    # Oman
    "muscat": "OM", "salalah": "OM", "sohar": "OM",
    # Bahrain
    "bahrain": "BH", "khalifa bin salman": "BH",
    # India (origin)
    "nhava sheva": "IN", "jnpt": "IN", "mundra": "IN",
    "chennai": "IN", "kolkata": "IN", "kochi": "IN",
    "tuticorin": "IN", "vishakhapatnam": "IN", "vizag": "IN",
    "pipavav": "IN", "kandla": "IN",
    # Other
    "singapore": "SG", "colombo": "LK", "rotterdam": "NL",
    "hamburg": "DE", "felixstowe": "GB", "antwerp": "BE",
    "new york": "US", "los angeles": "US",
}

# ─────────────────────────────────────────────────────────────────────────────
# COMMODITY → HS CODE MAP  (common India–GCC exports)
# ─────────────────────────────────────────────────────────────────────────────

COMMODITY_HS: dict[str, str] = {
    "black pepper":     "090411",
    "white pepper":     "090412",
    "cardamom":         "090831",
    "turmeric":         "091030",
    "cinnamon":         "090611",
    "cloves":           "090711",
    "nutmeg":           "090811",
    "ginger":           "091011",
    "cumin":            "090922",
    "coriander seeds":  "090921",
    "basmati rice":     "100630",
    "rice":             "100630",
    "wheat":            "100190",
    "sugar":            "170199",
    "raw sugar":        "170111",
    "cotton":           "520100",
    "granite":          "680223",
    "marble":           "680221",
    "cashew":           "080132",
    "cashew nuts":      "080132",
    "sesame":           "120740",
    "sesame seeds":     "120740",
    "coffee":           "090111",
    "tea":              "090210",
    "shrimp":           "030617",
    "prawns":           "030617",
    "fish":             "030389",
    "mango":            "080450",
    "onion":            "070310",
    "garlic":           "070320",
    "textiles":         "630900",
    "garments":         "620000",
    "leather":          "420000",
    "steel":            "720000",
    "aluminium":        "760000",
    "chemicals":        "290000",
    "pharmaceutical":   "300000",
    "medicine":         "300000",
    "machinery":        "840000",
    "auto parts":       "870000",
    "electronics":      "850000",
    "solar panels":     "854140",
}


# ─────────────────────────────────────────────────────────────────────────────
# PATTERNS
# ─────────────────────────────────────────────────────────────────────────────

_RE_FLAGS = re.IGNORECASE | re.MULTILINE

# Quantity: "500 kg", "2.5 MT", "1000 bags", "50 cartons"
_QTY = re.compile(
    r"""
    (?:qty|quantity|weight|volume|amount|order(?:ed)?|ship(?:ment)?|supply|deliver)
    [\s:—\-]*
    (?P<qty>[\d,]+(?:\.\d+)?)
    \s*
    (?P<unit>kg|kgs|kilogram|kilograms|mt|mts|metric\s*ton|tonne|tonnes|
             bags?|sacks?|pieces?|pcs|cartons?|ctns?|litres?|liters?|ltrs?|
             sets?|units?|nos?\.?|numbers?)
    """,
    _RE_FLAGS | re.VERBOSE,
)

# Standalone qty+unit not preceded by label
_QTY_BARE = re.compile(
    r"(?<!\w)(?P<qty>[\d,]+(?:\.\d+)?)\s*"
    r"(?P<unit>kg|kgs|mt|mts|metric\s*ton|tonnes?|bags?|pieces?|pcs|cartons?)(?!\w)",
    _RE_FLAGS,
)

# Incoterms
_INCOTERMS = re.compile(
    r"\b(?P<term>CIF|CFR|FOB|EXW|DDP|DAP|DAT|FCA|CPT|CIP|FAS)\b"
    r"(?:\s+(?P<port>[A-Z][A-Za-z\s]{2,30}))?",
    re.IGNORECASE,
)

# Payment terms
_PAYMENT = re.compile(
    r"\b(?:"
    r"LC\b|L/C\b|letter\s+of\s+credit|"
    r"TT\b|T/T\b|telegraphic\s+transfer|wire\s+transfer|bank\s+transfer|"
    r"CAD\b|cash\s+against\s+documents?|"
    r"DA\b|D/A\b|documents?\s+against\s+acceptance|"
    r"DP\b|D/P\b|documents?\s+against\s+payment|"
    r"OA\b|open\s+account|"
    r"advance\s+payment|payment\s+in\s+advance|100\s*%\s*advance|"
    r"usance|sight\b"
    r")",
    _RE_FLAGS,
)

_PAYMENT_CLEAN: dict[str, str] = {
    "lc": "LC", "l/c": "LC", "letter of credit": "LC",
    "tt": "TT", "t/t": "TT", "telegraphic transfer": "TT",
    "wire transfer": "TT", "bank transfer": "TT",
    "cad": "CAD", "cash against documents": "CAD",
    "da": "DA", "d/a": "DA", "documents against acceptance": "DA",
    "dp": "DP", "d/p": "DP", "documents against payment": "DP",
    "oa": "OA", "open account": "OA",
    "advance payment": "Advance", "payment in advance": "Advance",
    "100% advance": "Advance",
}

# Currency
_CURRENCY = re.compile(
    r"\b(?P<currency>USD|US\$|EUR|€|GBP|£|AED|INR|₹|SAR|QAR|OMR|KWD|BHD|SGD)\b",
    _RE_FLAGS,
)
_CURRENCY_NORM: dict[str, str] = {
    "us$": "USD", "€": "EUR", "£": "GBP", "₹": "INR",
}

# Unit price
_UNIT_PRICE = re.compile(
    r"(?:unit\s*price|price\s*per\s*(?:unit|kg|mt|ton|bag|piece|ctn)|rate)[\s:—\-]*"
    r"(?:USD|EUR|AED|INR|SAR|\$|€|₹)?\s*"
    r"(?P<price>[\d,]+(?:\.\d{1,4})?)",
    _RE_FLAGS,
)

# Total value
_TOTAL = re.compile(
    r"(?:total\s*(?:value|amount|price|cost)|grand\s*total|invoice\s*value)[\s:—\-]*"
    r"(?:USD|EUR|AED|INR|SAR|\$|€|₹)?\s*"
    r"(?P<total>[\d,]+(?:\.\d{1,2})?)",
    _RE_FLAGS,
)

# HS code
_HS = re.compile(
    r"(?:hs\s*code|hs\s*no|harmonized\s*(?:code|tariff)|hts)[\s:.\-]*"
    r"(?P<hs>\d{4}[.\-]?\d{2}[.\-]?\d{0,4})",
    _RE_FLAGS,
)

# Delivery / shipment date
_DATE = re.compile(
    r"(?:delivery|shipment|dispatch|ship(?:ping)?\s*date|required\s*by|"
    r"eta|etd|ex(?:pected)?\s*delivery)[\s:—\-]*"
    r"(?P<date>\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}"
    r"|(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[\s\-.,]*\d{1,2}[\s,]*\d{2,4}"
    r"|\d{4}[\/\-]\d{2}[\/\-]\d{2})",
    _RE_FLAGS,
)

# Buyer name from message headers
_BUYER = re.compile(
    r"(?:[Ff][Rr][Oo][Mm]|[Bb][Uu][Yy][Ee][Rr]|[Cc][Oo][Nn][Ss][Ii][Gg][Nn][Ee][Ee]|[Ii][Mm][Pp][Oo][Rr][Tt][Ee][Rr]|[Oo][Rr][Dd][Ee][Rr][Ee][Dd]\s*[Bb][Yy]|[Cc][Ll][Ii][Ee][Nn][Tt]|[Cc][Oo][Mm][Pp][Aa][Nn][Yy]|[Pp][Aa][Rr][Tt][Yy]|[Ss][Hh][Ii][Pp]\s*[Tt][Oo]|[Ss][Oo][Ll][Dd]\s*[Tt][Oo]|[Bb][Ii][Ll][Ll]\s*[Tt][Oo])(?:\s*\([^)]*\))?[\s:—\-]+"
    r"(?P<name>[A-Z][A-Za-z\s&.,()-]{3,60}?)(?=\n|,|\.|$)"
)

# Destination port
_DEST_PORT = re.compile(
    r"(?:port\s+of\s+(?:discharge|destination|delivery)|destination\s+port|"
    r"discharge\s+port|consigned\s+to)[\s:—\-]*"
    r"(?P<port>[A-Z][A-Za-z\s]{2,30}?)(?=\n|,|\.|$)",
    _RE_FLAGS,
)

# Country mentions
_COUNTRY = re.compile(
    r"\b(?P<country>UAE|United Arab Emirates|Saudi Arabia|KSA|Qatar|Kuwait|"
    r"Oman|Bahrain|Singapore|Germany|Netherlands|United Kingdom|UK|USA|"
    r"United States|India)\b",
    _RE_FLAGS,
)

_COUNTRY_ISO: dict[str, str] = {
    "uae": "AE", "united arab emirates": "AE",
    "saudi arabia": "SA", "ksa": "SA",
    "qatar": "QA", "kuwait": "KW", "oman": "OM", "bahrain": "BH",
    "singapore": "SG", "germany": "DE", "netherlands": "NL",
    "united kingdom": "GB", "uk": "GB",
    "usa": "US", "united states": "US",
    "india": "IN",
}


# ─────────────────────────────────────────────────────────────────────────────
# EXTRACTOR
# ─────────────────────────────────────────────────────────────────────────────

class RuleBasedExtractor:

    @classmethod
    def extract(cls, text: str, org_overrides: dict | None = None) -> dict:
        """
        Extract structured PO fields from raw text.

        Parameters
        ----------
        text : str
            Raw text from OCR or WhatsApp message.
        org_overrides : dict | None
            Per-org extraction rules loaded from organizations.extraction_rules.
            Expected shape (all keys optional):
              {
                "commodity_hs":      {"basmati rice": "100630", ...},
                "unit_aliases":      {"bag": "BAG", ...},
                "default_incoterms": "CIF",
                "default_currency":  "USD"
              }
            Org-level commodity_hs entries take priority over the global
            COMMODITY_HS map, so each export house can have their own
            product description → HS code mappings that override the defaults.
        """
        if not text or not text.strip():
            return cls._empty_result()

        # Merge global commodity map with org-specific overrides.
        # Org overrides go in last so they win on any key conflict.
        org_overrides     = org_overrides or {}
        org_commodity_hs  = {**COMMODITY_HS, **org_overrides.get("commodity_hs", {})}
        org_unit_aliases  = org_overrides.get("unit_aliases", {})

        tl = text.lower()

        # ── Extract fields ───────────────────────────────────────────────────
        qty, unit           = cls._extract_quantity(text)
        unit                = org_unit_aliases.get(unit, unit)   # apply org unit alias
        description         = cls._extract_commodity(text, org_commodity_hs)
        hs_code             = cls._extract_hs(text, description, org_commodity_hs)
        incoterms, inc_port = cls._extract_incoterms(text)
        dest_port           = cls._extract_dest_port(text) or inc_port
        payment_terms       = cls._extract_payment(text)
        currency            = cls._extract_currency(text)
        unit_price          = cls._extract_unit_price(text)
        total_value         = cls._extract_total(text)
        delivery_date       = cls._extract_date(text)
        buyer_name          = cls._extract_buyer(text)
        buyer_country       = cls._extract_buyer_country(text, dest_port)

        # Apply org-level defaults for fields still missing after extraction
        if not incoterms and org_overrides.get("default_incoterms"):
            incoterms = org_overrides["default_incoterms"]
        if not currency and org_overrides.get("default_currency"):
            currency = org_overrides["default_currency"]

        # ── Build items list ─────────────────────────────────────────────────
        items = []
        if description or qty:
            items.append({
                "description":       description or "Unknown",
                "quantity":          qty,
                "unit":              cls._normalise_unit(unit),
                "unit_price":        unit_price or 0.0,
                "hs_code":           hs_code,
                "hs_code_source":    "rule_based" if hs_code else "unknown",
                "hs_confidence":     85 if hs_code else 0,
                "country_of_origin": "IN",
            })

        # ── Confidence scoring ───────────────────────────────────────────────
        scores = {
            "items":         25 if items and description else (10 if items else 0),
            "buyer":         10 if buyer_name else 0,
            "currency":       5 if currency else 0,
            "payment_terms": 15 if payment_terms else 0,
            "incoterms":     15 if incoterms else 0,
            "destination":   15 if dest_port else 0,
            "price":         10 if (unit_price or total_value) else 0,
            "dates":          5 if delivery_date else 0,
        }
        confidence = float(sum(scores.values()))

        # ── Clarifications for missing blocking fields ────────────────────────
        clarifications = []
        if not items:
            clarifications.append({
                "field":    "items",
                "question": "What product(s) and quantity are you ordering?",
                "blocking": True,
            })
        if not dest_port:
            clarifications.append({
                "field":    "destination_port",
                "question": "What is the destination port or city for this shipment?",
                "blocking": True,
            })
        if not payment_terms:
            clarifications.append({
                "field":    "payment_terms",
                "question": "What are the payment terms? (e.g., LC at sight, TT advance, CAD)",
                "blocking": True,
            })
        if not incoterms:
            clarifications.append({
                "field":    "incoterms",
                "question": "What are the delivery terms? (e.g., CIF Jebel Ali, FOB Mumbai)",
                "blocking": True,
            })
        if not buyer_name:
            clarifications.append({
                "field":    "buyer_name",
                "question": "Could you confirm your company name?",
                "blocking": False,
            })
        if not unit_price and not total_value:
            clarifications.append({
                "field":    "unit_price",
                "question": f"What is the price per {cls._normalise_unit(unit) or 'unit'}?",
                "blocking": False,
            })

        warnings = []
        if confidence < 40:
            warnings.append("Low confidence — insufficient structured data in message")
        if items and not hs_code:
            warnings.append(f"HS code not found for '{description}' — will be AI-suggested")

        return {
            "buyer_name":           buyer_name,
            "buyer_country":        buyer_country,
            "buyer_address":        None,
            "items":                items,
            "currency":             currency or "USD",
            "total_value":          total_value or 0.0,
            "payment_terms":        payment_terms,
            "incoterms":            incoterms,
            "destination_port":     dest_port,
            "destination_country":  buyer_country,
            "delivery_date":        delivery_date,
            "special_instructions": None,
            "confidence":           confidence,
            "confidence_breakdown": {
                "buyer_info":       scores["buyer"] + scores["currency"],
                "items":            scores["items"] + scores["price"],
                "commercial_terms": scores["payment_terms"] + scores["incoterms"],
                "logistics":        scores["destination"] + scores["dates"],
            },
            "warnings":               warnings,
            "requires_clarification": clarifications,
            "_source":                "rule_based",
        }

    @classmethod
    def _empty_result(cls) -> dict:
        return {
            "buyer_name": None, "buyer_country": None, "buyer_address": None,
            "items": [], "currency": "USD", "total_value": 0.0,
            "payment_terms": None, "incoterms": None,
            "destination_port": None, "destination_country": None,
            "delivery_date": None, "special_instructions": None,
            "confidence": 0.0,
            "confidence_breakdown": {"buyer_info": 0, "items": 0, "commercial_terms": 0, "logistics": 0},
            "warnings": ["Empty input — no text to extract from"],
            "requires_clarification": [],
            "_source": "rule_based",
        }

    # ── Field extractors ────────────────────────────────────────────────────

    @classmethod
    def _extract_quantity(cls, text: str) -> tuple[float, str]:
        m = _QTY.search(text)
        if m:
            return cls._parse_num(m.group("qty")), m.group("unit").lower()
        m = _QTY_BARE.search(text)
        if m:
            return cls._parse_num(m.group("qty")), m.group("unit").lower()
        return 0.0, ""

    @classmethod
    def _extract_commodity(cls, text: str, commodity_map: dict | None = None) -> str:
        """Match known commodities first, then fallback to noun extraction."""
        cmap = commodity_map if commodity_map is not None else COMMODITY_HS
        tl = text.lower()
        best = ""
        for commodity in sorted(cmap.keys(), key=len, reverse=True):
            if commodity in tl:
                best = commodity.title()
                break
        if best:
            return best
        m = re.search(
            r"(?:shipment\s+of|supply\s+of|order\s+for|need|require)\s+"
            r"(?:[\d,]+\s*(?:kg|mt|bags?|pieces?)?\s*)?"
            r"(?P<item>[A-Z][A-Za-z\s]{2,30}?)(?=\s*(?:shipment|to|\.|\n|,|$))",
            text, re.IGNORECASE,
        )
        if m:
            return m.group("item").strip().title()
        return ""

    @classmethod
    def _extract_hs(cls, text: str, description: str,
                    commodity_map: dict | None = None) -> Optional[str]:
        m = _HS.search(text)
        if m:
            return re.sub(r"[.\-]", "", m.group("hs"))
        cmap = commodity_map if commodity_map is not None else COMMODITY_HS
        if description:
            return cmap.get(description.lower())
        return None

    @classmethod
    def _extract_incoterms(cls, text: str) -> tuple[Optional[str], Optional[str]]:
        m = _INCOTERMS.search(text)
        if m:
            term = m.group("term").upper()
            port = m.group("port").strip().title() if m.group("port") else None
            return term, port
        return None, None

    @classmethod
    def _extract_dest_port(cls, text: str) -> Optional[str]:
        m = _DEST_PORT.search(text)
        if m:
            return m.group("port").strip().title()
        tl = text.lower()
        for port in sorted(PORT_COUNTRY.keys(), key=len, reverse=True):
            if port in tl:
                return port.title()
        return None

    @classmethod
    def _extract_payment(cls, text: str) -> Optional[str]:
        m = _PAYMENT.search(text)
        if not m:
            return None
        raw = m.group(0).lower().strip()
        for k, v in _PAYMENT_CLEAN.items():
            if raw.startswith(k):
                return v
        return m.group(0).upper()

    @classmethod
    def _extract_currency(cls, text: str) -> Optional[str]:
        m = _CURRENCY.search(text)
        if not m:
            return None
        raw = m.group("currency")
        return _CURRENCY_NORM.get(raw.lower(), raw.upper())

    @classmethod
    def _extract_unit_price(cls, text: str) -> Optional[float]:
        m = _UNIT_PRICE.search(text)
        if m:
            return cls._parse_num(m.group("price"))
        return None

    @classmethod
    def _extract_total(cls, text: str) -> Optional[float]:
        m = _TOTAL.search(text)
        if m:
            return cls._parse_num(m.group("total"))
        return None

    @classmethod
    def _extract_date(cls, text: str) -> Optional[str]:
        m = _DATE.search(text)
        if not m:
            return None
        raw = m.group("date").strip()
        for fmt in ("%d/%m/%Y", "%d-%m-%Y", "%Y/%m/%d", "%Y-%m-%d",
                    "%d/%m/%y", "%d-%m-%y"):
            try:
                return datetime.strptime(raw, fmt).strftime("%Y-%m-%d")
            except ValueError:
                pass
        return raw

    @classmethod
    def _extract_buyer(cls, text: str) -> Optional[str]:
        m = _BUYER.search(text)
        if m:
            name = m.group("name").strip().rstrip(".,")
            if len(name) > 3:
                return name
        return None

    @classmethod
    def _extract_buyer_country(cls, text: str, dest_port: Optional[str]) -> Optional[str]:
        if dest_port:
            dp_lower = dest_port.lower()
            for p, country in PORT_COUNTRY.items():
                if p in dp_lower:
                    return country
        m = _COUNTRY.search(text)
        if m:
            return _COUNTRY_ISO.get(m.group("country").lower())
        return None

    # ── Helpers ─────────────────────────────────────────────────────────────

    @staticmethod
    def _parse_num(s: str) -> float:
        try:
            return float(s.replace(",", ""))
        except (ValueError, AttributeError):
            return 0.0

    @staticmethod
    def _normalise_unit(unit: str) -> str:
        mapping = {
            "kg": "KG", "kgs": "KG", "kilogram": "KG", "kilograms": "KG",
            "mt": "MT", "mts": "MT", "metric ton": "MT", "tonne": "MT", "tonnes": "MT",
            "bag": "BAG", "bags": "BAG", "sack": "BAG", "sacks": "BAG",
            "piece": "PCS", "pieces": "PCS", "pcs": "PCS",
            "carton": "CTN", "cartons": "CTN", "ctns": "CTN", "ctn": "CTN",
            "litre": "LTR", "litres": "LTR", "liter": "LTR", "liters": "LTR", "ltrs": "LTR",
        }
        return mapping.get((unit or "").lower().strip(), (unit or "").upper())

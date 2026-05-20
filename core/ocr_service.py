"""
TradeOS — OCR Service
======================
Document text extraction pipeline.
  1. Fast path  : pypdf  (text-based PDFs, zero GPU)
  2. Fallback   : PaddleOCR HTTP service (scanned / image-only PDFs)
  3. LLM pass   : table detection + field correction on extracted raw text

All public surfaces are async.  Import from here — never duplicate in main.py.
"""

from __future__ import annotations

import base64
import io
import json
import os
from typing import Any

import httpx


# ─────────────────────────────────────────────
# CONFIG (read from env — no hard-coding)
# ─────────────────────────────────────────────

OCR_SERVICE_URL   = os.getenv("OCR_SERVICE_URL",  "http://ocr:8100/extract")
OCR_TIMEOUT_S     = int(os.getenv("OCR_TIMEOUT_S", "60"))
PYPDF_ENABLED     = os.getenv("PYPDF_ENABLED", "true").lower() != "false"


# ─────────────────────────────────────────────
# LOW-LEVEL EXTRACTORS
# ─────────────────────────────────────────────

async def extract_text_pypdf(file_bytes: bytes) -> str:
    """
    Extract text from a text-based PDF using pypdf.
    Fast, no GPU, no network call.
    Returns empty string if pypdf is unavailable or the PDF is image-only.
    """
    if not PYPDF_ENABLED:
        return ""
    try:
        from pypdf import PdfReader          # pip install pypdf
        reader = PdfReader(io.BytesIO(file_bytes))
        pages  = [page.extract_text() or "" for page in reader.pages]
        return "\n".join(pages).strip()
    except ImportError:
        return ""
    except Exception as exc:
        print(f"[OCR/pypdf] extraction error: {exc}")
        return ""


async def extract_text_paddle(file_bytes: bytes, mime_type: str) -> str:
    """
    Call the PaddleOCR sidecar service (ocr:8100) for scanned / image-only documents.
    Expects the service to accept {"file_b64": str, "mime_type": str}
    and return {"text": str, "confidence": float}.
    """
    try:
        payload = {
            "file_b64":  base64.b64encode(file_bytes).decode(),
            "mime_type": mime_type or "application/pdf",
        }
        async with httpx.AsyncClient(timeout=OCR_TIMEOUT_S) as client:
            resp = await client.post(OCR_SERVICE_URL, json=payload)
            resp.raise_for_status()
            data = resp.json()
            return data.get("text", "")
    except httpx.HTTPStatusError as exc:
        print(f"[OCR/paddle] HTTP {exc.response.status_code}: {exc.response.text[:200]}")
        return ""
    except Exception as exc:
        print(f"[OCR/paddle] service unavailable: {exc}")
        return ""


# ─────────────────────────────────────────────
# TABLE & STRUCTURE DETECTION  (LLM pass)
# ─────────────────────────────────────────────

async def extract_tables_from_text(raw_text: str) -> list[dict]:
    """
    Ask the LLM to pull tabular structures out of the raw OCR text.
    Returns a list of {"headers": [...], "rows": [[...]]} dicts.
    Gracefully returns [] on any failure so the pipeline keeps running.
    """
    if not raw_text.strip():
        return []
    try:
        from main import LLMRouter, parse_llm_json  # avoids circular at import time

        result = await LLMRouter.complete(
            system_prompt=(
                "You are a document parser specialising in trade documents. "
                "Extract all table structures as JSON arrays. "
                "Handle merged cells, rotated headers, and partial columns."
            ),
            user_prompt=(
                f"Extract tables from this document text:\n\n{raw_text}"
            ),
            output_schema={"tables": [{"headers": [], "rows": []}]},
            temperature=0.0,
        )
        return parse_llm_json(result["text"], "table extraction").get("tables", [])
    except Exception as exc:
        print(f"[OCR/tables] LLM table extraction failed: {exc}")
        return []


async def detect_stamps(file_bytes: bytes) -> dict:
    """
    Vision-model stub for stamp / signature detection.
    Plug in Azure Document Intelligence or a fine-tuned YOLO model here.
    """
    # Production: send file_bytes to vision model, parse bounding boxes
    return {"has_signature": None, "has_stamp": None, "stamp_text": None}


# ─────────────────────────────────────────────
# LLM STRUCTURED EXTRACTION PASS
# ─────────────────────────────────────────────

async def llm_extract_fields(raw_text: str, tables: list[dict]) -> dict:
    """
    Run a structured LLM pass over the raw OCR text + detected tables to
    produce a typed, normalised extraction dict.
    Returns {} on failure; callers must handle gracefully.
    """
    if not raw_text.strip():
        return {}
    try:
        from main import LLMRouter, parse_llm_json

        result = await LLMRouter.complete(
            system_prompt=(
                "You are an expert in international trade documentation. "
                "Extract all relevant fields from export/import documents. "
                "For HS codes, always include your confidence (0-100). "
                "Normalize quantities to standard units."
            ),
            user_prompt=(
                f"Document text:\n{raw_text}\n\n"
                f"Tables:\n{json.dumps(tables)}\n\n"
                "Extract all fields."
            ),
            output_schema={
                "doc_type": "string",
                "reference_number": "string",
                "date": "string",
                "parties": {
                    "exporter": {"name": "", "address": "", "iec": ""},
                    "importer": {"name": "", "address": ""},
                },
                "items": [{
                    "description": "",
                    "hs_code": "",
                    "hs_confidence": 0,
                    "quantity": 0,
                    "unit": "",
                    "unit_price": 0,
                    "total_value": 0,
                    "country_of_origin": "",
                }],
                "total_value": 0,
                "currency": "",
                "payment_terms": "",
                "incoterms": "",
                "special_conditions": [],
                "overall_confidence": 0,
                "extraction_warnings": [],
            },
            temperature=0.0,
        )
        return parse_llm_json(result["text"], "document extraction")
    except Exception as exc:
        print(f"[OCR/llm_extract] failed: {exc}")
        return {}


# ─────────────────────────────────────────────
# PUBLIC API — used by DocumentIntelligenceEngine
# ─────────────────────────────────────────────

async def extract_text(file_bytes: bytes, mime_type: str) -> str:
    """
    Extract raw text from a document using the best available method.

    Priority:
      1. pypdf   — fast, free, works for text-layer PDFs
      2. Paddle  — GPU-accelerated OCR sidecar for scanned docs
      3. Raises  — if both fail (don't silently return placeholder)

    Args:
        file_bytes: Raw bytes of the uploaded file.
        mime_type:  MIME type string, e.g. "application/pdf".

    Returns:
        Non-empty string of extracted text.

    Raises:
        RuntimeError: If no extractor could produce output.
    """
    # 1 — pypdf (text-based PDF)
    if mime_type in ("application/pdf", "pdf", "", None):
        text = await extract_text_pypdf(file_bytes)
        if text:
            print(f"[OCR] pypdf extracted {len(text)} chars")
            return text

    # 2 — PaddleOCR sidecar (scanned PDF / image)
    text = await extract_text_paddle(file_bytes, mime_type)
    if text:
        print(f"[OCR] paddle extracted {len(text)} chars")
        return text

    raise RuntimeError(
        "Could not extract text from document. "
        "Ensure the PDF is not password-protected or purely scanned "
        "without the OCR service running."
    )


async def full_document_pipeline(file_bytes: bytes, mime_type: str) -> dict:
    """
    End-to-end document intelligence pipeline:
      extract_text → detect_tables → detect_stamps → llm_extract_fields

    Returns a dict with keys:
      raw_text, tables, stamps, extracted (typed fields from LLM pass)

    Designed to be called by DocumentIntelligenceEngine.extract_from_file().
    """
    raw_text  = await extract_text(file_bytes, mime_type)
    tables    = await extract_tables_from_text(raw_text)
    stamps    = await detect_stamps(file_bytes)
    extracted = await llm_extract_fields(raw_text, tables)

    return {
        "raw_text":  raw_text,
        "tables":    tables,
        "stamps":    stamps,
        "extracted": extracted,
    }

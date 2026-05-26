"""
TradeOS — OCR Service  (core/ocr_service.py)
=============================================
Pure text-extraction pipeline — no LLM calls here.
LLM-based field extraction lives in POExtractionAgent (services/api/main.py).

Extraction priority:
  1. pypdf        — instant, zero-GPU, works for text-layer PDFs
  2. PaddleOCR    — GPU-accelerated sidecar for scanned / image-only docs
  3. RuntimeError — raised clearly so callers know extraction failed

Public API used by DocumentIntelligenceEngine.extract_from_file():
  extract_text(file_bytes, mime_type)  →  str
  full_document_pipeline(...)          →  {raw_text, tables, stamps}
"""

from __future__ import annotations

import base64
import io
import os
from typing import Any

import httpx


# ─────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────

OCR_SERVICE_URL = os.getenv("OCR_SERVICE_URL", "http://ocr:8100/extract")
OCR_TIMEOUT_S   = int(os.getenv("OCR_TIMEOUT_S", "60"))
PYPDF_ENABLED   = os.getenv("PYPDF_ENABLED", "true").lower() != "false"


# ─────────────────────────────────────────────
# EXTRACTORS
# ─────────────────────────────────────────────

async def extract_text_pypdf(file_bytes: bytes) -> str:
    """
    Extract text from a text-based PDF using pypdf.
    Returns empty string if pypdf is unavailable or the PDF is image-only.
    """
    if not PYPDF_ENABLED:
        return ""
    try:
        from pypdf import PdfReader
        reader = PdfReader(io.BytesIO(file_bytes))
        pages  = [page.extract_text() or "" for page in reader.pages]
        text   = "\n".join(pages).strip()
        print(f"[OCR/pypdf] extracted {len(text)} chars from {len(reader.pages)} pages")
        return text
    except ImportError:
        print("[OCR/pypdf] pypdf not installed — pip install pypdf")
        return ""
    except Exception as exc:
        print(f"[OCR/pypdf] error: {exc}")
        return ""


async def extract_text_paddle(file_bytes: bytes, mime_type: str) -> str:
    """
    Call the PaddleOCR sidecar (ocr:8100) for scanned / image-only documents.
    The service must accept POST {"file_b64": str, "mime_type": str}
    and return {"text": str}.
    """
    try:
        payload = {
            "file_b64":  base64.b64encode(file_bytes).decode(),
            "mime_type": mime_type or "application/pdf",
            "api_key":   os.getenv("OCR_API_KEY", ""),   
        }
        async with httpx.AsyncClient(timeout=OCR_TIMEOUT_S) as client:
            resp = await client.post(OCR_SERVICE_URL, json=payload)
            resp.raise_for_status()
            text = resp.json().get("text", "")
            print(f"[OCR/paddle] extracted {len(text)} chars")
            return text
    except httpx.HTTPStatusError as exc:
        print(f"[OCR/paddle] HTTP {exc.response.status_code}: {exc.response.text[:200]}")
        return ""
    except Exception as exc:
        print(f"[OCR/paddle] service unavailable: {exc}")
        return ""


async def detect_stamps(file_bytes: bytes) -> dict:
    """
    Stub for stamp / signature detection.
    Plug in Azure Document Intelligence or a fine-tuned YOLO model here.
    """
    return {"has_signature": None, "has_stamp": None, "stamp_text": None}


# ─────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────

async def extract_text(file_bytes: bytes, mime_type: str) -> str:
    """
    Extract raw text from a document using the best available method.

    Priority:
      1. pypdf  — fast, text-layer PDFs
      2. Paddle — scanned / image PDFs via sidecar

    Raises RuntimeError if both fail.
    """
    # 1 — pypdf (text-layer PDF)
    if mime_type in ("application/pdf", "pdf", "", None):
        text = await extract_text_pypdf(file_bytes)
        if text:
            return text

    # 2 — PaddleOCR sidecar
    text = await extract_text_paddle(file_bytes, mime_type)
    if text:
        return text

    raise RuntimeError(
        "Could not extract text from document. "
        "Check that pypdf is installed (pip install pypdf) and the PDF "
        "is not password-protected. For scanned PDFs ensure the OCR "
        "sidecar (ocr:8100) is running."
    )


async def full_document_pipeline(file_bytes: bytes, mime_type: str) -> dict:
    """
    Extract text and detect structural elements from a document.
    Returns:
        raw_text : str   — full extracted text (used by POExtractionAgent)
        tables   : list  — placeholder; real table parsing done by LLM in POExtractionAgent
        stamps   : dict  — stamp / signature detection result
    Note: LLM-based field extraction is NOT done here.
          It is the responsibility of POExtractionAgent.
    """
    from core.redis_client import cache_get, cache_set
    import hashlib
    
    # 1. Check Cache
    file_hash = hashlib.sha256(file_bytes).hexdigest()
    cache_key = f"ocr:{file_hash}"
    cached_result = await cache_get(cache_key)
    if cached_result:
        print(f"[OCR] ⚡ Cache hit for file: {cache_key}")
        return cached_result

    raw_text = await extract_text(file_bytes, mime_type)
    stamps   = await detect_stamps(file_bytes)

    result = {
        "raw_text": raw_text,
        "tables":   [],      # POExtractionAgent's LLM pass handles table parsing
        "stamps":   stamps,
        "extracted": {},     # intentionally empty — POExtractionAgent fills this
    }
    
    # 2. Set Cache
    await cache_set(cache_key, result, ttl_seconds=300)
    
    return result

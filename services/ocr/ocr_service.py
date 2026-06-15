"""
TradeOS — PaddleOCR Sidecar
Accepts: POST /extract { file_b64, mime_type }
Returns: { text }
"""
from __future__ import annotations
import base64, io, os
from typing import Any
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

_ocr = None
def get_ocr():
    global _ocr
    if _ocr is None:
        from paddleocr import PaddleOCR
        _ocr = PaddleOCR(use_angle_cls=True, lang="en", use_gpu=False, show_log=False)
    return _ocr

class ExtractRequest(BaseModel):
    file_b64: str
    mime_type: str = "application/pdf"
    api_key: str = ""

app = FastAPI(title="TradeOS OCR Sidecar", version="1.0.0")

@app.get("/health")
async def health(): return {"status": "ok"}

@app.post("/extract")
async def extract(req: ExtractRequest):
    try:
        file_bytes = base64.b64decode(req.file_b64)
        mime = req.mime_type.lower()
        text = _ocr_pdf(file_bytes) if "pdf" in mime else _ocr_image_bytes(file_bytes)
        return {"text": text}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))

def _ocr_image_bytes(image_bytes: bytes) -> str:
    import numpy as np
    from PIL import Image
    arr = np.array(Image.open(io.BytesIO(image_bytes)).convert("RGB"))
    return _flatten(get_ocr().ocr(arr, cls=True))

def _ocr_pdf(pdf_bytes: bytes) -> str:
    from pdf2image import convert_from_bytes
    import numpy as np
    pages = convert_from_bytes(pdf_bytes, dpi=200)
    return "\n\n".join(_flatten(get_ocr().ocr(np.array(p.convert("RGB")), cls=True)) for p in pages)

def _flatten(result: Any) -> str:
    lines = []
    if not result: return ""
    for page in result:
        if not page: continue
        for line in page:
            if line and len(line) >= 2 and line[1]:
                lines.append(str(line[1][0]))
    return "\n".join(lines)

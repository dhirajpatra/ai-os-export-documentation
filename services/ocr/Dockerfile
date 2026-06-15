FROM python:3.10-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    poppler-utils libglib2.0-0 libsm6 libxrender1 libxext6 libgl1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY ocr_service.py .

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8100/health')"

EXPOSE 8100
CMD ["uvicorn", "ocr_service:app", "--host", "0.0.0.0", "--port", "8100"]

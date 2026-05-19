# SKILL — TradeOS Phase 1 MVP
## WhatsApp intake · AI invoice · Packing list · Tracking dashboard · HITL approval

---

## What is already built (do not rebuild)

Phase 1 is **substantially complete**. The following files exist and are production-ready:

| File | What it contains |
|------|-----------------|
| `services/api/main.py` | FastAPI app, all 5 core agents, LLM router, WhatsApp webhook handler, killer demo endpoint |
| `core/workflow_engine.py` | Deterministic saga state machine (6-step PO→dispatch pipeline) |
| `core/memory.py` | Agent memory store, buyer/route profiles, memory observer |
| `core/prompt_registry.py` | Versioned prompts for all agents (v2–v4), fallback chains, fingerprint hashing |
| `core/rbac.py` | JWT auth, 8 roles, 25 permissions, approval rule engine, tenant resolver |
| `schemas/001_core_schema.sql` | Full PostgreSQL schema: orgs, users, orders, documents, workflows, approvals, audit_log, agent_memory |
| `docker-compose.yml` | Full infra stack: Postgres+pgvector, Redis, Kafka, Temporal, PaddleOCR, Ollama, ngrok |
| `requirements.txt` | All Python dependencies pinned |

**Goal of Phase 1:** Replace 50% of manual documentation staff workload.  
**Status:** Core pipeline complete. Missing pieces are listed under "What still needs building."

---

## Architecture — Phase 1

```
Ingestion
  WhatsApp Business API  ──┐
  Email IMAP/SMTP        ──┤
  PDF portal upload      ──┴──► Communication Agent
                                      │
                                      ▼
                            WorkflowEngine.run()
                            (deterministic saga)
                                      │
                    ┌─────────────────┼─────────────────┐
                    ▼                 ▼                  ▼
            POExtractionAgent   HSValidationAgent  DocGenerationAgent
            (LLM router)        (LLM router)       (LLM router)
                    │                 │                  │
                    └────────── SupervisorAgent ─────────┘
                                      │
                              HITLOrchestrator
                                      │
                        ┌─────────────┴──────────────┐
                        ▼                             ▼
                  confidence ≥ 92%           confidence < 92%
                  auto-dispatch              approval_requests table
                        │                             │
                        ▼                             ▼
               WhatsAppService.send()        Manager notified
               (buyer notification)          Diff viewer shown
                        │                             │
                        ▼                             ▼
               LogisticsAgent                 approve/reject/changes
               (shipment record)              WorkflowEngine.resume()
```

**Data stores used in Phase 1:**
- PostgreSQL: orders, order_items, documents, workflows, workflow_steps, approval_requests, audit_log, messages, shipments
- Redis: hot cache for tenant resolution, rate limiting
- S3/GCS: generated PDF storage (invoice, packing list)
- Kafka: workflow events → memory observer

---

## What still needs building in Phase 1

These are the gaps between the current codebase and a fully operational MVP:

### 1. PDF generation (CRITICAL — needed for killer demo)

The agents generate document data as JSON. That JSON must be rendered into actual downloadable PDFs.

**File to create:** `services/documents/pdf_renderer.py`

**Approach:** Use `weasyprint` (already in requirements.txt). Build an HTML template per document type and convert to PDF.

```python
# Pattern to follow
from weasyprint import HTML
import jinja2

class PDFRenderer:
    async def render_commercial_invoice(self, invoice_data: dict, org: dict) -> bytes:
        template = jinja2_env.get_template("commercial_invoice.html")
        html_str = template.render(**invoice_data, org=org)
        return HTML(string=html_str).write_pdf()

    async def render_packing_list(self, pl_data: dict, org: dict) -> bytes:
        ...
```

**Templates to create:**
- `templates/commercial_invoice.html` — UNCTAD-compliant, LC-ready layout
- `templates/packing_list.html` — matches invoice totals exactly

**Integration point:** After `DocGenerationAgent` returns JSON in `workflow_engine.py` → `step_generate_documents()`, call `PDFRenderer`, upload bytes to S3, store `storage_path` in `documents` table.

### 2. Database async session + SQLAlchemy models

All DB calls are currently stubbed with comments (`# In production: INSERT INTO ...`). These need real implementations.

**File to create:** `core/db/session.py`

```python
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

engine = create_async_engine(settings.DATABASE_URL, pool_size=20, max_overflow=10)
AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

async def get_db():
    async with AsyncSessionLocal() as session:
        yield session
```

**Files to create:** `core/db/models/` — one SQLAlchemy model per schema table. Map directly from `schemas/001_core_schema.sql`. Use `UUID` primary keys, `JSONB` for flexible fields, `TIMESTAMPTZ` for all timestamps.

**Integration:** Add `db: AsyncSession = Depends(get_db)` to FastAPI endpoints. Pass `db` into `WorkflowEngine` and all agents.

### 3. WhatsApp webhook — real tenant resolution

The webhook in `main.py` hardcodes `org_id`. Replace with:

```python
async def whatsapp_inbound(payload, background_tasks):
    messages = WhatsAppService.parse_inbound(payload.model_dump())
    for msg in messages:
        org_id = TenantResolver.resolve_phone(msg["from"])
        if not org_id:
            # Unknown number — send onboarding message
            await WhatsAppService.send_text(msg["from"], "Hi! To connect to TradeOS, ...")
            continue
        background_tasks.add_task(_process_inbound_whatsapp, msg, org_id=uuid.UUID(org_id))
```

**TenantResolver** is implemented in `core/rbac.py`. It needs to be backed by Redis:
```python
@classmethod
async def resolve_phone_async(cls, phone: str, redis) -> str | None:
    val = await redis.get(f"phone_org:{phone}")
    if val: return val.decode()
    # fallback to DB SELECT
    ...
```

### 4. Shipment tracking dashboard — frontend

A Next.js/React page that polls `GET /api/v1/shipments/{id}` and displays the 7-step tracker. The WebSocket endpoint `/ws/workflow/{id}` is already implemented in `main.py` for live step updates.

**Shipment status endpoint to add to `main.py`:**
```python
@app.get("/api/v1/shipments/{shipment_id}")
async def get_shipment(shipment_id: uuid.UUID, ctx = Depends(get_org_context)):
    # SELECT * FROM shipments WHERE id = shipment_id AND org_id = ctx.org_id
    # JOIN shipment_events
    ...
```

### 5. Approval UI — wire to API

The HITL approval interface (built as the interactive widget) needs to call the real API:

- `GET /api/v1/approvals` → populate the sidebar queue
- `POST /api/v1/approvals/{id}/action` → handle approve/reject/changes
- WebSocket `/ws/workflow/{id}` → live confidence updates

The `action_approval` endpoint in `main.py` needs to be completed — it currently returns a stub. It must:
1. Fetch approval from DB, verify user has `documents:approve` permission (use `check_permission()` from `core/rbac.py`)
2. Write `audit_log` entry
3. Update `approval_requests.status`
4. Signal Temporal workflow to resume (or use in-memory event in Phase 1)
5. If `field_overrides` present: re-run `DocGenerationAgent` with overrides

---

## Key integration: killer demo flow

The single endpoint that proves Phase 1 works:

```
POST /api/v1/workflow/po-to-dispatch
  body: po_text="500kg black tea, Dubai, LC payment, CIF"
        buyer_whatsapp="+971501234567"

Response:
{
  "workflow_id": "...",
  "status": "awaiting_approval",   ← or "completed" if confidence ≥ 92%
  "overall_confidence": 74.2,
  "extracted_order": { buyer, items, currency, terms... },
  "hs_validation": { validations, flags... },
  "documents": { commercial_invoice: {...}, packing_list: {...} },
  "hitl_decision": { decision, reason, requires_human },
  "steps": [ {step, status, ts}... ]
}
```

This endpoint is **fully implemented** in `main.py`. The only gap is that `documents` contains JSON, not PDF bytes. Add `PDFRenderer` (item 1 above) to close that gap.

---

## LLM provider setup

The `LLMRouter` in `main.py` tries providers in this order. Configure via environment:

```env
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
XAI_API_KEY=xai-...
XAI_MODEL=grok-4
XAI_BASE_URL=https://api.x.ai/v1
GEMINI_API_KEY=...
# For local Ollama fallback, no key needed — just run: ollama pull mistral
```

Priority order is in `Settings.LLM_CHAIN`. Do not hardcode a model anywhere in business logic. All prompts go through `PromptRegistry` in `core/prompt_registry.py`.

---

## Running Phase 1 locally

```bash
# 1. Infrastructure
docker compose up -d postgres redis kafka

# 2. Run schema
docker exec -i tradeos-postgres-1 psql -U tradeos tradeos < schemas/001_core_schema.sql

# 3. Environment
cp .env.example .env   # fill ANTHROPIC_API_KEY, JWT_SECRET, WHATSAPP_TOKEN

# 4. API
pip install -r requirements.txt
uvicorn services.api.main:app --reload --port 8000

# 5. Test killer demo (no WhatsApp needed)
curl -X POST http://localhost:8000/api/v1/workflow/po-to-dispatch \
  -F "po_text=500kg Basmati Rice, Dubai, CIF, USD 1.20/kg, LC at sight"
```

---

## Phase 1 completion checklist

- [ ] `core/db/session.py` — async SQLAlchemy session
- [ ] `core/db/models/` — all ORM models matching schema
- [ ] `services/documents/pdf_renderer.py` — weasyprint PDF from JSON
- [ ] `templates/commercial_invoice.html` — LC-compliant invoice template
- [ ] `templates/packing_list.html` — packing list template
- [ ] `POST /api/v1/approvals/{id}/action` — complete HITL action handler
- [ ] `GET /api/v1/shipments/{id}` — shipment status + events
- [ ] `TenantResolver` backed by Redis
- [ ] WhatsApp webhook — real org resolution
- [ ] Phase 1 demo: end-to-end from WhatsApp text → PDF invoice → WhatsApp reply ✓

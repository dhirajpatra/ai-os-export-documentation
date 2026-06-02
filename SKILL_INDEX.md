# SKILL — TradeOS Master Index
## Architecture overview · Cross-phase reference · Development guide

---

## What this repository is

TradeOS is an agentic AI operating system for India–GCC export businesses. It replaces manual documentation, WhatsApp-based workflows, and fragmented ERP systems with a multi-agent AI layer that operates autonomously and learns from every transaction.

**Core principle:** AI operates workflows. Humans supervise policy.

---

## Skills map

| Skill file | Phase | Covers |
|-----------|-------|--------|
| `SKILL_PHASE1_MVP.md` | Phase 1 MVP | WhatsApp intake, AI invoice + packing list, shipment tracking, HITL approval |
| `SKILL_PHASE2.md` | Phase 2 | Compliance AI, Finance AI, voice agents, Arabic documents, predictive analytics |
| `SKILL_PHASE3.md` | Phase 3 | Fully autonomous workflows, AI workforce orchestration, AI-native ERP, multi-company OS |

**Always read the skill file for the phase you are working on before writing any code.**

---

## Codebase map — what exists and where

```
tradeos/
│
├── services/
│   └── api/
│       └── main.py                ← SINGLE entry point for Phase 1
│           Contains:
│           • FastAPI app + all routes
│           • LLMRouter (OpenAI → Grok → Claude → Gemini → Ollama)
│           • BaseAgent (all agents extend this)
│           • POExtractionAgent
│           • HSCodeValidationAgent
│           • DocumentGenerationAgent
│           • DocumentIntelligenceEngine (OCR pipeline)
│           • HITLOrchestrator
│           • WhatsAppService
│           • KillerDemoWorkflow (deprecated — use WorkflowEngine directly)
│
├── core/
│   ├── workflow_engine.py         ← Deterministic saga state machine
│   │   Contains:
│   │   • WorkflowEngine (step executor, retry, compensation)
│   │   • WorkflowContext (shared state across steps)
│   │   • WorkflowStep (declarative step definition)
│   │   • build_po_to_dispatch_workflow() ← THE killer demo
│   │   • Temporal activity stubs (commented, for Phase 3)
│   │
│   ├── memory.py                  ← Agent memory layer (the moat)
│   │   Contains:
│   │   • AgentMemoryStore (upsert, recall, semantic search)
│   │   • MemoryRecord (single memory with embedding)
│   │   • BuyerMemoryProfile (per-buyer learned preferences)
│   │   • RouteMemoryProfile (per-route learned transit/compliance)
│   │   • MemoryObserver (auto-learns from workflow events)
│   │   • LocalEmbedder (sentence-transformers fallback)
│   │
│   ├── prompt_registry.py         ← Versioned prompt store
│   │   Contains:
│   │   • PromptRegistry (in-memory + DB backed)
│   │   • PromptRecord (versioned, with fingerprint + fallback chain)
│   │   • PromptTester (CI/CD gate before deploying new prompts)
│   │   • load_all_prompts() ← all production prompts registered here
│   │     Prompts: po_extraction v3, po_extraction_simple v1 (fallback),
│   │              hs_validate v2, commercial_invoice v4,
│   │              packing_list v2, country_trade_check v2,
│   │              draft_buyer_notification v2
│   │
│   └── rbac.py                    ← Auth + permissions + approval chains
│       Contains:
│       • Role enum (owner|admin|manager|operator|viewer|customs|finance|logistics)
│       • PERMISSIONS dict (25 named permissions → allowed roles)
│       • check_permission() / require_permission()
│       • ApprovalRule + DEFAULT_APPROVAL_RULES
│       • evaluate_approval_rules()
│       • TokenPayload + create_access_token() + decode_access_token()
│       • TenantResolver (phone → org_id, apikey → org_id)
│
├── schemas/
│   └── 001_core_schema.sql        ← Full PostgreSQL schema
│       Tables:
│       organizations, users, contacts, products,
│       orders, order_items, documents, workflows, workflow_steps,
│       approval_requests, audit_log,
│       agent_memory (with vector(1536) column),
│       prompt_registry, messages, shipments, shipment_events,
│       hs_codes, country_trade_rules
│
├── docker-compose.yml             ← Full infra stack
│   Services:
│   • api (FastAPI, port 8000)
│   • postgres (pgvector/pgvector:pg16, port 5432)
│   • redis (redis:7-alpine, port 6379)
│   • temporal (auto-setup:1.22, port 7233)
│   • temporal-ui (port 8088)
│   • ocr (PaddleOCR service, port 8100)
│   • ollama (local LLM, port 11434)
│   • ngrok (WhatsApp dev proxy, profile: dev)
│
└── requirements.txt               ← All Python deps pinned
    Key packages: fastapi, asyncpg, sqlalchemy[asyncio], alembic,
                  pgvector, temporalio, anthropic, openai,
                  google-generativeai, paddleocr, weasyprint,
                  sentence-transformers, python-jose, boto3
```

---

## Architecture layers (all phases)

### Layer 1 — Ingestion
WhatsApp Business API, Email IMAP/SMTP, PDF portal, Voice (Phase 2+)

All inbound channels funnel into the **Communication Agent** which normalises input to English and extracts intent.

### Layer 2 — Workflow engine
`core/workflow_engine.py` — deterministic, not LLM-orchestrated.

Steps are pure async functions. LLMs are tools called within steps. The engine manages: dependency ordering, retries with exponential backoff, timeouts, HITL pausing, compensation (rollback) on failure.

**Never add business logic to the engine itself.** Each step calls an agent. Agents call LLMs. This separation is the key to maintainability as models change.

### Layer 3 — Agents
Each agent is a class extending `BaseAgent` in `services/api/main.py`.

Agents are stateless. They receive input, call `LLMRouter.complete()` with a prompt from `PromptRegistry`, and return structured output. They write observations to `AgentMemoryStore`.

**Agent list (Phase 1 built, Phase 2+ extended):**
- `POExtractionAgent` — extracts structured data from any PO format
- `HSCodeValidationAgent` — validates and corrects HS codes per route
- `DocumentGenerationAgent` — generates invoice, packing list, COO, BL draft
- `ComplianceAgent` (stub → full in Phase 2) — regulatory checks
- `FinanceAgent` (stub → full in Phase 2) — LC verification, invoice matching
- `LogisticsAgent` (stub → full in Phase 2) — carrier booking, tracking
- `SupervisorAgent` — confidence scoring, HITL routing

### Layer 4 — HITL (Human-in-the-Loop)
`HITLOrchestrator` in `services/api/main.py` decides: auto-approve, soft-review, block.

In Phase 3, replaced by `PolicyEngine` with dynamic trust-based thresholds.

Approval data stored in `approval_requests` table. All human actions written to `audit_log`.

### Layer 5 — Memory
`core/memory.py` — this is the moat.

Every completed workflow trains the system. Observations are stored in `agent_memory` with pgvector embeddings for semantic recall. Agents recall context before running, personalising output without prompt engineering per customer.

### Layer 6 — Prompt registry
`core/prompt_registry.py` — all prompts versioned, fingerprinted, and fallback-chained.

When a model changes behaviour, bump the prompt version. Old version remains active until new version passes `PromptTester` evaluation. Never hardcode prompts in agent code.

### Layer 7 — Data
- PostgreSQL (pgvector/pg16): all structured data + vector embeddings
- Redis: hot cache, rate limiting, session store
- S3/GCS: document files (PDF invoices, scanned POs, certificates)
- SSE / WebSockets: event bus (workflow events → memory observer → agent learning)

### Layer 8 — Integrations (Phase 2+)
- Carriers: DHL, FedEx, Maersk APIs
- ERP: Tally Prime XML Gateway, Zoho Books REST API v3
- Gov portals: DGFT, ICEGATE, UAE Federal Customs
- Banks: LC document exchange (SWIFT MT700 alignment)

---

## LLM router — critical design rule

`LLMRouter` in `services/api/main.py` tries providers in this order:

```
1. OpenAI GPT-4o      (priority 1)
2. xAI Grok           (priority 2)
3. Anthropic Claude   (priority 3)
4. Google Gemini      (priority 4)
5. Ollama local       (priority 5 — always-on fallback)
```

**Never reference a specific model name in business logic.** Never bypass `LLMRouter`. Models change every 6 months. The router is the only coupling point.

Change provider priority in `Settings.LLM_CHAIN`. Change models per provider there too. No other file needs to change.

---

## Prompt registry — critical design rule

Every prompt lives in `core/prompt_registry.py` → `load_all_prompts()`.

**Never hardcode a prompt string in an agent.** Agents call:
```python
prompt = PromptRegistry.get("agent_name", "prompt_key")
rendered = prompt.render(**template_vars)
result = await self.llm.complete(system_prompt=prompt.system_prompt, user_prompt=rendered)
```

To update a prompt: add a new `PromptRecord` with `version += 1`, set `is_active=True`. Keep the old version with `is_active=True` until the new one passes `PromptTester`. Then deprecate the old.

---

## RBAC — critical design rule

Every API endpoint must verify the calling user's role before acting:

```python
@app.post("/api/v1/documents/approve/{id}")
async def approve_document(id: uuid.UUID, ctx = Depends(get_org_context)):
    require_permission(ctx.role, "documents:approve")   # raises 403 if not allowed
    # ... proceed
```

Every DB query must scope to `org_id`:
```python
# ALWAYS
SELECT * FROM orders WHERE id = $1 AND org_id = $2

# NEVER
SELECT * FROM orders WHERE id = $1
```

---

## Event system — SSE events

All workflow events are dispatched via SSE/WebSockets. The `MemoryObserver` subscribes and auto-learns.

| Event / Topic | Emitted by | Consumed by |
|-------|-----------|-------------|
| `tradeos.workflow.completed` | WorkflowEngine | MemoryObserver, BriefingEngine |
| `tradeos.workflow.step.completed` | WorkflowEngine | MemoryObserver, monitoring |
| `tradeos.approval.approved` | HITL endpoint | MemoryObserver (learns overrides) |
| `tradeos.shipment.delivered` | LogisticsAgent | MemoryObserver (learns transit times) |
| `tradeos.payment.received` | FinanceAgent | MemoryObserver (learns payment patterns) |
| `tradeos.compliance.flag` | ComplianceAgent | MemoryObserver (learns risk patterns) |

---

## Testing strategy

### Unit tests
Each agent: mock `LLMRouter.complete()`, assert structured output shape and confidence.

### Integration tests
`build_po_to_dispatch_workflow()` with a real test PO text against a test database.

### Prompt regression tests
`PromptTester.evaluate()` runs before every prompt version bump. Minimum 90% pass rate.

### HITL tests
Verify the three decision paths: auto-approve, soft-review, block — with crafted confidence scores.

### Memory tests
Feed 10 completed workflows, verify semantic recall returns relevant context.

---

## Environment variables (all phases)

```env
# LLM providers
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
GROQ_API_KEY=gsk_...
GROQ_MODEL=llama-3.3-70b-versatile
GROQ_BASE_URL=https://api.groq.com/openai/v1
XAI_API_KEY=xai-...
XAI_MODEL=grok-4.3
XAI_BASE_URL=https://api.x.ai/v1
GEMINI_API_KEY=...

# Database
DATABASE_URL=postgresql+asyncpg://tradeos:tradeos@localhost/tradeos

# Cache
REDIS_URL=redis://localhost:6379/0

# Workflow
TEMPORAL_HOST=localhost:7233

# Storage
S3_BUCKET=tradeos-documents
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...

# WhatsApp
WHATSAPP_TOKEN=...
WHATSAPP_PHONE_ID=...
WHATSAPP_VERIFY_TOKEN=...

# Auth
JWT_SECRET=...
JWT_EXPIRE_MINS=480

# OCR (optional - defaults to LLM extraction if not set)
PADDLE_OCR_URL=http://localhost:8100

# HITL thresholds (override defaults)
CONFIDENCE_THRESHOLD_AUTO=92.0
CONFIDENCE_THRESHOLD_HUMAN=70.0
APPROVAL_TIMEOUT_HOURS=4

# Phase 2+ (GCC data sources)
DGFT_API_KEY=...
OFAC_CACHE_PATH=/tmp/ofac_sdn.json

# Phase 3+ (multi-company)
ENABLE_MULTI_COMPANY=false
GROUP_BRIEFING_TIME=07:00
```

---

## Quick reference — key API endpoints

| Phase | Method | Path | Description |
|-------|--------|------|-------------|
| 1 | POST | `/api/v1/workflow/po-to-dispatch` | Killer demo — full pipeline |
| 1 | GET  | `/api/v1/approvals` | List pending HITL approvals |
| 1 | POST | `/api/v1/approvals/{id}/action` | Approve / reject / changes |
| 1 | POST | `/api/v1/documents/extract` | Upload doc → AI extraction |
| 1 | POST | `/api/v1/documents/generate` | Generate invoice/packing list |
| 1 | POST | `/api/v1/compliance/hs-validate` | Validate HS codes |
| 1 | GET  | `/ws/workflow/{id}` | WebSocket live step updates |
| 1 | POST | `/api/v1/webhooks/whatsapp` | WhatsApp inbound handler |
| 2 | POST | `/api/v1/finance/lc-verify` | LC document verification |
| 2 | GET  | `/api/v1/analytics/delay-prediction/{id}` | Shipment delay prediction |
| 2 | GET  | `/api/v1/analytics/revenue-forecast` | Revenue forecast |
| 3 | POST | `/api/v1/erp/query` | Natural language ERP query |
| 3 | POST | `/api/v1/erp/action` | Execute confirmed ERP action |
| 3 | GET  | `/api/v1/workforce/health` | Agent performance metrics |
| 3 | GET  | `/api/v1/briefing/today` | Today's AI ops briefing |

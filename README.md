# TradeOS

**Agentic AI operating system for India–GCC export documentation.**
"AI operates workflows. Humans supervise."

TradeOS replaces manual export documentation, WhatsApp-based operations, and
fragmented ERP systems with a multi-agent AI layer that automates purchase
order intake, HS code validation, invoice/packing list generation, compliance
checks, and shipment tracking — with human approval gates on anything below
a confidence threshold.

---

## Two editions

TradeOS ships as two separate things. This split is intentional, not
incidental — it's how we let customers run parts of the stack on their own
hardware while keeping the compliance/documentation intelligence centralized
and maintained.

| | **TradeOS Local** (this repo, open source) | **TradeOS Cloud** (private) |
|---|---|---|
| **Who runs it** | Customer, on their own machine/server | Us, as a managed service |
| **Requires** | Docker, optionally a GPU for OCR/local LLM | Nothing from the customer |
| **Data store** | SQLite (`local_schema.sql`) — stays on device | PostgreSQL + pgvector, multi-tenant |
| **PO extraction** | Rule-based (regex) + template matching — zero LLM cost for repeat buyers | Full LLM pipeline (Claude/GPT-4o/Groq) with tuned prompts |
| **Compliance / HS / doc generation** | Calls our MCP API | Runs natively — this *is* the MCP server |
| **Prompts, regulatory KB, learned cross-org data** | Not included | Proprietary — this is what you're paying for |
| **Networking** | Needs outbound access to `TRADEOS_CLOUD_URL` for rules sync + MCP calls | N/A |

**In short:** the local edition handles ingestion, cheap/deterministic
extraction, and local storage. Anything that requires real trade-compliance
reasoning — HS validation, invoice/packing list generation, country rules,
sanctions screening — is a metered API call to TradeOS Cloud via MCP. This
repo never contains our system prompts, regulatory knowledge base, or
learned per-org intelligence.

If you're looking for the managed cloud product, see
[cloud.tradeos.in](https://cloud.tradeos.in) — this repo is the self-hosted
local component only.

---

## Architecture

```
┌─────────────────────────────┐        ┌──────────────────────────────┐
│  TradeOS Local (this repo)  │        │  TradeOS Cloud (private)     │
│  customer's machine         │        │  our infra                   │
│                              │        │                               │
│  WhatsApp/Email intake       │        │  MCP API                     │
│  RuleBasedExtractor (regex)  │──MCP──▶│    /mcp/hs/validate           │
│  TemplateMatcher (learned)   │  calls │    /mcp/rules/manifest        │
│  SQLite local storage        │◀───────│    /mcp/rules/bundle/{v}     │
│  Ollama (optional local LLM) │        │                               │
│  PaddleOCR (CPU or GPU)      │        │  Prompt Registry (proprietary)│
│                              │        │  Regulatory KB / HS codes     │
│  rules_sync.py ──pulls──────▶│        │  Multi-org learning           │
└─────────────────────────────┘        └──────────────────────────────┘
```

**Extraction is three-layered, cheapest first** (see
`services/agents/po_extraction.py` in the full pipeline):

1. **Rule-based** (regex/keyword) — ₹0, handles ~60–70% of repeat shipments
2. **Template matching** — ₹0, per-buyer learned patterns from prior extractions
3. **MCP / LLM fallback** — metered call to TradeOS Cloud, only for novel
   formats, new buyers, or ambiguous text

This repo ships layers 1 and 2 in full. Layer 3 is a thin MCP client — no
prompts, no model calls, live here.

---

## What's in this repo

```
├── local_schema.sql              SQLite schema — orders, contacts, documents,
│                                  workflows, agent_memory (no embeddings),
│                                  po_templates, hitl_corrections
├── core/
│   ├── rules_sync.py              Pulls versioned HS/compliance bundles
│   │                              from TradeOS Cloud (non-fatal if offline)
│   ├── mcp_auth.py                Client-side MCP key handling
│   └── redis_client.py            Optional local cache
├── services/
│   ├── agents/
│   │   ├── rule_based_extractor.py   Zero-LLM PO field extraction
│   │   └── template_matcher.py       Learned buyer-format templates
│   ├── integrations/
│   │   └── whatsapp.py               WhatsApp Business / Twilio intake
│   └── ocr/                          PaddleOCR sidecar (CPU or GPU image)
└── docker-compose.yml              Local stack: app + Ollama + OCR + SQLite volume
```

**Not in this repo** (cloud-only):

- `core/prompt_registry.py` — all system prompts and confidence rubrics
- `services/compliance/`, regulatory knowledge base, HS/country-rule datasets
- Full `HSCodeValidationAgent` / `DocumentGenerationAgent` LLM logic
- Any customer FAQ/company-specific content
- Cross-org learning and the shared knowledge graph

---

## Requirements

- Docker + Docker Compose
- A TradeOS Cloud API key (`tos_live_...`) — generated during onboarding via
  `POST /api/v1/mcp/keys/generate` against the cloud API, **not** shipped in
  this image
- **Optional:** an NVIDIA GPU for faster OCR (PaddleOCR) and to run a larger
  local LLM via Ollama instead of the default small fallback model. CPU-only
  works fine at lower throughput.

---

## Quick start

```bash
git clone https://github.com/<your-org>/tradeos-local.git
cd tradeos-local

cp .env.example .env
# Fill in:
#   TRADEOS_MCP_KEY=tos_live_...       (from your cloud account)
#   TRADEOS_CLOUD_URL=https://cloud.tradeos.in
#   LOCAL_ORG_ID=<uuid from onboarding>
#   WHATSAPP_TOKEN=...                 (if using WhatsApp intake)

# CPU (default):
docker compose up -d

# GPU (faster OCR + local LLM):
docker compose --profile gpu up -d
```

Check it came up clean:

```bash
docker compose exec api curl -sf http://localhost:8000/health
docker compose exec api curl -s http://ollama:11434/api/tags
```

Rules sync (HS codes, compliance flags) pulls automatically every
`RULES_SYNC_INTERVAL_H` hours (default 6) — see `core/rules_sync.py`. If
`TRADEOS_CLOUD_URL` is unreachable, the local install keeps running on
whatever rules it last synced; nothing blocks on connectivity.

---

## How data flows

- **Stays local, never leaves the device:** raw PO text/files, `audit_log`,
  `workflows`/`workflow_steps` (internal saga state), document file bytes.
- **Synced up to cloud** (so your cloud account has a full picture):
  contacts, orders, `po_templates`, `agent_memory` (without embeddings —
  cloud re-embeds), `hitl_corrections` (this is what improves the shared
  model over time).
- **Synced down from cloud:** HS codes, compliance rules, prompt updates
  (never the prompt *text* itself — only what's needed to render), logistics
  vendor profiles.

See the `-- [SYNC UP]`, `-- [SYNC DOWN]`, `-- [LOCAL ONLY]` annotations in
`local_schema.sql` for the exact table-by-table breakdown.

---

## Security notes

- Each local install gets its **own** MCP API key at onboarding — never a
  shared or embedded key baked into this image.
- Local SQLite file is not encrypted at rest by default; if your deployment
  needs that, put it on an encrypted volume.
- `bank_details` and similar sensitive fields are expected to be encrypted at
  the application layer before insertion — see comments in `local_schema.sql`.

---

## License

[Choose and state license here — e.g. Apache 2.0 / AGPL, depending on how
much reuse you want to permit for the local-extraction components vs.
requiring an MCP subscription to be useful.]

## Support

Self-hosted local edition: open an issue in this repo.
Cloud API / MCP access / billing: contact support via your TradeOS Cloud account.

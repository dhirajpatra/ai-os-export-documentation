# SKILL — TradeOS Phase 2
## Compliance AI · Finance AI · Voice agents · Arabic workflows · Predictive analytics

---

## Prerequisites — Phase 1 must be complete

Before starting Phase 2, confirm Phase 1 checklist is done:
- Async DB session + ORM models working
- PDF generation producing real files
- HITL approval endpoint fully wired
- WhatsApp webhook resolving real org_id
- End-to-end demo: text PO → invoice PDF → WhatsApp reply

Phase 2 builds on the same `WorkflowEngine`, `PromptRegistry`, `AgentMemoryStore`, and `LLMRouter` from Phase 1. Do not modify those core files except to extend them.

---

## Architecture additions in Phase 2

```
Phase 1 pipeline (unchanged)
           │
           ▼
    WorkflowEngine
    ┌──────────────────────────────────────┐
    │  Step: compliance_check  ← NEW       │
    │  Step: finance_validate  ← NEW       │
    │  Step: voice_parse       ← NEW       │
    └──────────────────────────────────────┘
           │
    ┌──────┴──────────────┐
    ▼                     ▼
ComplianceAgent       FinanceAgent
(already stubbed,     (already stubbed,
 needs full impl)      needs full impl)
    │                     │
    ▼                     ▼
RegulatoryKnowledgeGraph   ERPConnector
(Neo4j or Postgres JSONB)  (Tally · Zoho)
    │
    ▼
PredictiveAnalyticsService  ← NEW
(delay prediction, revenue forecasting)
```

**New services to create in Phase 2:**
- `services/compliance/` — full compliance agent + regulatory knowledge base
- `services/finance/` — full finance agent + ERP integrations
- `services/voice/` — voice command pipeline
- `services/analytics/` — predictive analytics layer
- `services/arabic/` — Arabic document generation and formatting

---

## 1. Compliance AI — full implementation

### What is already built

`ComplianceAgent` exists as a stub in `services/api/main.py`. The prompt is registered in `core/prompt_registry.py` at key `compliance_agent/country_trade_check/v2`. The `country_trade_rules` and `hs_codes` tables exist in the schema with pgvector embeddings.

### What to build

**File:** `services/compliance/agent.py`

Extend `BaseAgent` from `services/api/main.py`:

```python
class ComplianceAgentV2(BaseAgent):
    name = "compliance_agent"

    async def run(self, input_data: dict) -> dict:
        # 1. HS code validation (already in Phase 1 via HSValidationAgent)
        # 2. Country-level trade check (use registered prompt)
        # 3. Sanctions screening
        # 4. Regulatory knowledge graph query
        # 5. Permit requirements
        # 6. DGFT policy check
        # 7. GCC-specific rules
        ...
```

**File:** `services/compliance/regulatory_kb.py`

Regulatory Knowledge Base — loaded from official sources, updated periodically:

```python
class RegulatoryKnowledgeBase:
    """
    Stores and queries trade rules semantically.
    Backed by hs_codes and country_trade_rules tables (see schema).
    Uses pgvector for semantic HS code search.
    """

    async def search_hs_codes(self, description: str, top_k: int = 5) -> list[dict]:
        # Embed the description, cosine similarity search on hs_codes.embedding
        ...

    async def get_route_rules(self, from_country: str, to_country: str,
                               hs_prefix: str | None = None) -> list[dict]:
        # SELECT * FROM country_trade_rules WHERE from_country=$1 AND to_country=$2
        ...

    async def check_sanctions(self, entity_name: str, country: str) -> dict:
        # OFAC SDN list check (cached, refreshed daily)
        ...

    async def get_permits_required(self, hs_code: str, to_country: str) -> list[str]:
        # Returns list of required permits/certificates
        ...
```

**Data sources to integrate (all public APIs / downloadable datasets):**

| Source | What it provides | Update frequency |
|--------|-----------------|-----------------|
| DGFT API | Export policy, IEC data, LUT status | Daily |
| ICEGATE | Shipping bill status, customs clearance | Real-time |
| UAE Federal Customs | GCC Tariff Schedule (8-digit) | Monthly |
| Saudi ZATCA | VAT rules, import duties | Monthly |
| WCO HS Database | 6-digit codes + descriptions | Annually |
| OFAC SDN List | Sanctions entities | Daily |

**File:** `services/compliance/data_loader.py`

```python
class ComplianceDataLoader:
    async def refresh_dgft_policy(self): ...
    async def refresh_ofac_sdn(self): ...
    async def refresh_gcc_tariffs(self, country: str): ...
    async def seed_hs_codes_with_embeddings(self): ...  # one-time bulk load
```

**New workflow step** to insert into `core/workflow_engine.py` after `validate_hs`:

```python
WorkflowStep(
    name        = "compliance_check",
    agent       = "compliance_agent",
    run_fn      = step_compliance_check,
    max_retries = 2,
    timeout_s   = 45,
    depends_on  = ["validate_hs"],
)
```

---

## 2. Finance AI — full implementation

### What is already built

`FinanceAgent` stub exists in `services/api/main.py`. No Finance-specific prompts are in `core/prompt_registry.py`. The `documents` table handles LC documents. The schema supports invoice matching via the `documents` table and `order_items`.

### What to build

**File:** `services/finance/agent.py`

```python
class FinanceAgentV2(BaseAgent):
    name = "finance_agent"

    async def run(self, input_data: dict) -> dict:
        task = input_data["task"]
        handlers = {
            "lc_verification":    self._verify_lc,
            "invoice_matching":   self._match_invoice,
            "payment_reminder":   self._draft_reminder,
            "credit_risk":        self._assess_credit_risk,
            "forex_rate":         self._apply_forex,
        }
        return await handlers[task](input_data)

    async def _verify_lc(self, data: dict) -> dict:
        # Parse LC document via DocumentIntelligenceEngine
        # Check: expiry date vs earliest ship date
        # Check: partial shipment clause vs available stock
        # Check: description matches LC field exactly
        # Check: amount within LC tolerance (usually ±5%)
        # Return: clearance status + specific violations
        ...

    async def _assess_credit_risk(self, data: dict) -> dict:
        # Query agent_memory for buyer payment history
        # Query buyer's order history from DB
        # Return: risk score 0-100, payment behavior, credit limit suggestion
        ...
```

**File:** `services/finance/erp_connectors.py`

```python
class TallyConnector:
    """
    Tally Prime integration via Tally XML Gateway (port 9000).
    Sync: invoices, receipts, ledger entries.
    """
    BASE_URL = "http://localhost:9000"

    async def push_invoice(self, invoice_data: dict) -> dict:
        xml = self._build_invoice_xml(invoice_data)
        async with httpx.AsyncClient() as client:
            resp = await client.post(self.BASE_URL, content=xml,
                                     headers={"Content-Type": "text/xml"})
        return self._parse_tally_response(resp.text)

    async def fetch_ledger(self, from_date: str, to_date: str) -> list[dict]: ...
    async def create_receipt(self, payment: dict) -> dict: ...


class ZohoConnector:
    """Zoho Books REST API v3."""
    BASE_URL = "https://books.zoho.in/api/v3"

    async def create_invoice(self, invoice: dict) -> dict: ...
    async def create_contact(self, contact: dict) -> dict: ...
    async def get_invoice_status(self, invoice_id: str) -> dict: ...
    async def record_payment(self, payment: dict) -> dict: ...
```

**New prompts to register** in `core/prompt_registry.py`:

```python
PromptRegistry.register(PromptRecord(
    agent_name  = "finance_agent",
    prompt_key  = "verify_lc_document",
    version     = 1,
    system_prompt = """
You are a senior trade finance specialist with 20 years LC verification experience.
Analyze the Letter of Credit against the order details.
Check all UCP 600 compliance requirements...
""",
    user_template = "LC Data:\n{lc_json}\n\nOrder Data:\n{order_json}",
    output_schema = {
        "lc_status": "compliant|discrepant|expired|insufficient",
        "discrepancies": [{"field": "", "lc_says": "", "order_says": "", "severity": ""}],
        "can_proceed": True,
        "actions_required": []
    }
))
```

**New API endpoints** to add to `main.py`:

```python
@app.post("/api/v1/finance/lc-verify")
async def verify_lc(order_id: uuid.UUID, lc_file: UploadFile, ctx = Depends(get_org_context)):
    ...

@app.get("/api/v1/finance/invoices")
async def list_invoices(status: str | None = None, ctx = Depends(get_org_context)):
    ...

@app.post("/api/v1/finance/payment-reminder/{invoice_id}")
async def trigger_payment_reminder(invoice_id: uuid.UUID, ctx = Depends(get_org_context)):
    ...
```

---

## 3. Voice agents

**Goal:** "Ship 500 kg spice mix to Dubai on LC" spoken into phone → full order workflow triggered.

**File:** `services/voice/pipeline.py`

```python
class VoicePipeline:
    """
    Speech → text → intent extraction → workflow trigger.
    WhatsApp voice notes are the primary delivery channel.
    """

    async def process_voice_note(self, audio_bytes: bytes, lang: str = "auto") -> dict:
        # Step 1: Transcribe via Whisper (OpenAI) or local whisper.cpp
        transcript = await self._transcribe(audio_bytes, lang)

        # Step 2: Language detection + translation to English if Arabic/Hindi
        english_text = await self._translate_if_needed(transcript, lang)

        # Step 3: Intent classification
        intent = await self._classify_intent(english_text)

        # Step 4: Route to appropriate workflow
        if intent["type"] == "new_order":
            return await self._trigger_po_workflow(intent, english_text)
        elif intent["type"] == "shipment_query":
            return await self._answer_shipment_query(intent)
        elif intent["type"] == "document_request":
            return await self._trigger_doc_generation(intent)

    async def _transcribe(self, audio: bytes, lang: str) -> str:
        # OpenAI Whisper API or local whisper.cpp via subprocess
        ...
```

**WhatsApp voice note handling** — add to `WhatsAppService.parse_inbound()`:

```python
if msg["type"] == "audio":
    audio_id = msg["audio"]["id"]
    audio_bytes = await cls._download_media(audio_id)
    return {"type": "voice", "audio_bytes": audio_bytes, "from": msg["from"]}
```

**New prompt** in `core/prompt_registry.py`:

```python
PromptRegistry.register(PromptRecord(
    agent_name   = "voice_agent",
    prompt_key   = "extract_voice_intent",
    version      = 1,
    system_prompt= """
Extract structured intent from spoken trade commands.
The speaker may be an exporter, freight forwarder, or buyer.
Commands will be informal, abbreviated, in mixed language.
""",
    user_template = "Transcript:\n{transcript}\n\nExtract intent.",
    output_schema = {
        "type": "new_order|shipment_query|document_request|payment_query|other",
        "confidence": 0,
        "extracted_data": {},
        "clarification_needed": []
    }
))
```

---

## 4. Arabic workflows — full document generation

### What is already built

Translation from Arabic → English is handled by the `CommunicationAgent` using `deep-translator`. Buyer WhatsApp messages in Arabic are already translated before PO extraction.

### What to build

Arabic documents are needed for GCC buyers who require invoices, COOs, and shipping docs in Arabic.

**File:** `services/arabic/document_formatter.py`

```python
class ArabicDocumentFormatter:
    """
    Format trade documents for Arabic-language delivery.
    RTL layout, Arabic numerals, Hijri date option,
    GCC-specific invoice styles.
    """

    async def render_arabic_invoice(self, invoice_data: dict) -> bytes:
        # 1. Translate field values via LLM (not just translate — adapt business terminology)
        arabic_data = await self._translate_for_business(invoice_data)
        # 2. Render HTML template with RTL CSS
        html = arabic_invoice_template.render(**arabic_data)
        # 3. Use weasyprint with Arabic font (Amiri or Cairo)
        return HTML(string=html).write_pdf()

    async def _translate_for_business(self, data: dict) -> dict:
        # Prompt specifically for trade terminology translation
        # e.g. "Packing List" → "قائمة التعبئة" (not a generic translation)
        ...
```

**New prompt** for Arabic trade terminology:

```python
PromptRegistry.register(PromptRecord(
    agent_name   = "arabic_agent",
    prompt_key   = "translate_trade_document",
    version      = 1,
    system_prompt= """
You are a bilingual international trade expert (Arabic/English).
Translate trade document fields using correct business Arabic terminology.
Use Gulf/GCC Arabic register, not Egyptian or Levantine.
Maintain numbers in Arabic-Indic numerals (٠١٢٣٤٥٦٧٨٩) for amounts.
""",
    ...
))
```

**Arabic HTML template** (`templates/arabic_invoice.html`):
- `dir="rtl"` on root element
- Google Fonts: Amiri (formal documents) or Cairo (modern style)
- Arabic-Indic numerals for amounts: use JS `toLocaleString('ar-AE')` or Python's `babel`

---

## 5. Predictive analytics

**File:** `services/analytics/predictor.py`

```python
class PredictiveAnalyticsService:

    async def predict_shipment_delay(self, shipment: dict) -> dict:
        """
        Uses historical route + carrier data from agent_memory.
        Features: carrier, route, season, port congestion, vessel type.
        Model: simple gradient boosting (sklearn) trained on shipment_events table.
        """
        features = await self._extract_features(shipment)
        delay_prob = self.delay_model.predict_proba([features])[0][1]
        return {
            "delay_probability": round(delay_prob * 100, 1),
            "expected_delay_days": self.delay_model.predict([features])[0],
            "factors": self._explain_factors(features),
        }

    async def forecast_revenue(self, org_id: str, months: int = 3) -> dict:
        """
        Simple time-series on completed orders.
        Uses orders table grouped by month.
        ARIMA or exponential smoothing via statsmodels.
        """
        ...

    async def score_customer_risk(self, contact_id: str) -> dict:
        """
        Combines: payment history (from agent_memory), order frequency,
        dispute count (from audit_log), country risk.
        Returns: risk_score 0-100, recommended credit limit.
        """
        buyer_mem = await memory_store.search(
            query="payment behavior credit risk",
            scope_type="contact",
            scope_id=contact_id
        )
        ...
```

**New API endpoints:**

```python
@app.get("/api/v1/analytics/delay-prediction/{shipment_id}")
async def predict_delay(shipment_id: uuid.UUID, ctx = Depends(get_org_context)):
    ...

@app.get("/api/v1/analytics/revenue-forecast")
async def revenue_forecast(months: int = 3, ctx = Depends(get_org_context)):
    ...

@app.get("/api/v1/analytics/customer-risk/{contact_id}")
async def customer_risk(contact_id: uuid.UUID, ctx = Depends(get_org_context)):
    ...
```

---

## Phase 2 completion checklist

- [ ] `services/compliance/agent.py` — full ComplianceAgentV2
- [ ] `services/compliance/regulatory_kb.py` — RegulatoryKnowledgeBase with pgvector search
- [ ] `services/compliance/data_loader.py` — DGFT, OFAC, GCC tariff ingestion
- [ ] Compliance workflow step added to `core/workflow_engine.py`
- [ ] `services/finance/agent.py` — LC verification, invoice matching, credit risk
- [ ] `services/finance/erp_connectors.py` — Tally + Zoho integrations
- [ ] Finance prompts registered in `core/prompt_registry.py`
- [ ] `services/voice/pipeline.py` — Whisper → intent → workflow trigger
- [ ] WhatsApp voice note handler in `WhatsAppService`
- [ ] `services/arabic/document_formatter.py` — RTL PDF generation
- [ ] Arabic invoice + packing list HTML templates
- [ ] `services/analytics/predictor.py` — delay prediction + revenue forecast + risk scoring
- [ ] All new API endpoints added to `main.py`
- [ ] All new prompts added to `core/prompt_registry.py`

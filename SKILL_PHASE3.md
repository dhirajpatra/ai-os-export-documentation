# SKILL — TradeOS Phase 3
## Fully autonomous workflows · AI workforce orchestration · AI-native export ERP · Multi-company cloud OS

---

## Prerequisites — Phases 1 and 2 must be complete

Before starting Phase 3, confirm these Phase 2 outputs are operational:
- `ComplianceAgentV2` running with live DGFT/OFAC/GCC data
- `FinanceAgentV2` with Tally/Zoho ERP integrations live
- `VoicePipeline` handling WhatsApp voice notes
- Arabic RTL document generation working end-to-end
- `PredictiveAnalyticsService` producing delay predictions and revenue forecasts
- Agent memory store accumulating real buyer/route/HS code observations

Phase 3 does not replace Phase 1 or 2 components. It builds an orchestration layer above them, adds multi-company tenancy, and transforms the system from a document automation tool into a full AI operating system for trade.

---

## What Phase 3 is

Phase 2 automates documents and validates compliance. The human still manages relationships, monitors dashboards, and decides strategy.

Phase 3 inverts that. The AI manages operations end-to-end. The human receives briefings, sets policy, and handles escalations. Every workflow that previously needed a human touch point — unless legally mandated — runs autonomously.

```
Phase 2:  Human initiates → AI executes → Human reviews → Human approves → AI sends
Phase 3:  AI initiates → AI executes → AI self-reviews → AI approves (if confidence ≥ 98%)
                                           → Human receives briefing summary
                                           → Human intervenes only on exceptions
```

---

## Architecture — Phase 3 additions

```
                    ┌────────────────────────────────┐
                    │   AI Workforce Orchestrator     │  ← NEW: coordinates all agents
                    │   (multi-agent supervisor)      │      as a managed "workforce"
                    └──────────────┬─────────────────┘
                                   │
          ┌────────────────────────┼────────────────────────┐
          ▼                        ▼                         ▼
  AutonomousWorkflow        WorkforceTerminal          BriefingEngine
  (zero-touch execution)    (browser-only UI)          (daily AI summaries)
          │                        │                         │
          ▼                        ▼                         ▼
  PolicyEngine             RoleAgentInterface         ExecutiveReport
  (rules → auto/escalate)  (per-role AI assistant)   (WhatsApp / email)

                    ┌────────────────────────────────┐
                    │   Multi-Company Cloud OS        │  ← NEW: org hierarchy
                    │   Parent → Subsidiaries         │
                    └──────────────┬─────────────────┘
                                   │
          ┌────────────────────────┼────────────────────────┐
          ▼                        ▼                         ▼
  CrossOrgAnalytics        ConsolidatedReporting      SharedKnowledgeGraph
  (group-level insights)   (multi-entity finance)     (compliance rules shared)

                    ┌────────────────────────────────┐
                    │   AI-Native Export ERP          │  ← NEW: replaces ERP UI
                    │   Conversational interface      │
                    └──────────────┬─────────────────┘
                                   │
          ┌────────────────────────┼────────────────────────┐
          ▼                        ▼                         ▼
  NLQueryEngine            EntityManager              AutoReconciliation
  ("show me all overdue")  (contacts, products)       (ledger balancing)
```

---

## 1. Fully autonomous workflows

### Concept

In Phase 1 and 2, every workflow pauses at HITL checkpoints. In Phase 3, the system earns the right to bypass those checkpoints through accumulated trust: high memory confidence for this buyer, validated HS codes, clean compliance history, known carrier, known route.

The `PolicyEngine` decides — for each workflow instance — whether HITL is needed. It replaces the static `cfg.CONFIDENCE_THRESHOLD_AUTO`.

### File: `services/autonomous/policy_engine.py`

```python
class PolicyEngine:
    """
    Dynamic HITL threshold based on accumulated trust signals.
    Each signal independently raises or lowers the effective threshold.
    Trust is earned per buyer, per route, per product category.
    """

    async def evaluate(self, ctx: WorkflowContext) -> PolicyDecision:
        signals = await self._collect_trust_signals(ctx)
        effective_threshold = self._compute_threshold(signals)
        decision = self._decide(ctx.overall_confidence, effective_threshold, signals)
        return PolicyDecision(
            auto_approve    = decision == "auto",
            effective_threshold = effective_threshold,
            signals         = signals,
            reason          = self._explain(signals, decision),
        )

    async def _collect_trust_signals(self, ctx: WorkflowContext) -> list[TrustSignal]:
        signals = []
        buyer_id = ctx.extracted_po.get("buyer_contact_id")

        # Signal 1: buyer payment history
        if buyer_id:
            mem = await memory_store.recall(
                "finance_agent", "risk_pattern", "payment_behavior",
                scope_type="contact", scope_id=buyer_id
            )
            if mem and mem.value.get("on_time_rate", 0) > 0.95:
                signals.append(TrustSignal("buyer_payment", boost=+8, label="100% on-time payment history"))

        # Signal 2: HS codes previously validated for this org
        for item in ctx.hs_validations.get("validations", []):
            code = item.get("validated_hs_code")
            if code:
                mem = await memory_store.recall("hs_validation_agent", "hs_code_learned", code)
                if mem and mem.observation_count >= 5:
                    signals.append(TrustSignal("hs_known", boost=+5,
                                               label=f"HS {code} validated {mem.observation_count}x"))

        # Signal 3: known route + carrier
        route = f"IN-{ctx.extracted_po.get('buyer_country', 'AE')[:2].upper()}"
        route_mem = await memory_store.search("transit_time", scope_type="route", scope_id=route, top_k=1)
        if route_mem:
            signals.append(TrustSignal("known_route", boost=+4, label=f"Route {route} used before"))

        # Signal 4: compliance clean history
        comp_flag_mem = await memory_store.recall("compliance_agent", "risk_pattern", "compliance_flag_count",
                                                   scope_type="contact", scope_id=buyer_id)
        if not comp_flag_mem or comp_flag_mem.value.get("count", 0) == 0:
            signals.append(TrustSignal("clean_compliance", boost=+6, label="No prior compliance flags"))

        # Signal 5: new buyer (negative signal)
        order_count_mem = await memory_store.recall("po_extraction_agent", "customer_preference",
                                                     "order_count", scope_type="contact", scope_id=buyer_id)
        if not order_count_mem or order_count_mem.value.get("count", 1) <= 1:
            signals.append(TrustSignal("new_buyer", boost=-15, label="First or second order"))

        return signals

    def _compute_threshold(self, signals: list) -> float:
        base = 92.0
        total_boost = sum(s.boost for s in signals)
        # Threshold lowers as trust accumulates (minimum 75%, maximum 98%)
        return max(75.0, min(98.0, base - total_boost))

    def _decide(self, confidence: float, threshold: float, signals: list) -> str:
        critical = any(s.boost < -10 for s in signals)
        if critical:
            return "require_human"
        return "auto" if confidence >= threshold else "require_human"


@dataclass
class TrustSignal:
    name:   str
    boost:  float   # positive = lowers threshold (more trust), negative = raises it
    label:  str


@dataclass
class PolicyDecision:
    auto_approve:          bool
    effective_threshold:   float
    signals:               list[TrustSignal]
    reason:                str
```

**Integration:** Replace `HITLOrchestrator.evaluate()` call in `core/workflow_engine.py` step `hitl_decision` with `PolicyEngine.evaluate()`. The result feeds the same `requires_human` flag — no other changes to the workflow.

### File: `services/autonomous/briefing_engine.py`

```python
class BriefingEngine:
    """
    Daily AI-generated operations briefing.
    Sent to owner/manager via WhatsApp and email at 7 AM.
    Replaces the dashboard as primary information surface.
    """

    async def generate_daily_briefing(self, org_id: str) -> dict:
        # 1. Query yesterday's completed workflows
        # 2. Query pending approvals
        # 3. Query overdue invoices
        # 4. Query active shipment delays
        # 5. Fetch revenue vs forecast
        # 6. LLM: synthesise into 5-bullet executive summary

        result = await LLMRouter.complete(
            system_prompt=(
                "You are a senior operations manager. Write a concise daily briefing. "
                "5 bullets max. Lead with the most critical item. "
                "Be direct — the reader has 30 seconds."
            ),
            user_prompt=f"Operations data:\n{json.dumps(ops_data, indent=2)}",
            max_tokens=400,
        )

        briefing_text = result["text"]

        # Send via WhatsApp to owner
        await WhatsAppService.send_text(owner_phone, f"📊 *Daily Ops Briefing*\n\n{briefing_text}")

        return {"briefing": briefing_text, "sent_at": datetime.utcnow().isoformat()}
```

**Schedule:** Add Celery beat task or Temporal cron workflow to trigger at 7 AM org timezone.

---

## 2. AI workforce orchestration

### Concept

Instead of agents running as isolated functions, Phase 3 treats agents as a managed "workforce" with roles, assignments, workloads, and performance metrics. The `WorkforceOrchestrator` allocates work, monitors agent health, and escalates when an agent underperforms.

### File: `services/workforce/orchestrator.py`

```python
class WorkforceOrchestrator:
    """
    Manages all agents as a coordinated team.
    Tracks: throughput, latency, confidence trends, failure rates.
    Reassigns work when an agent degrades.
    Alerts humans only when the whole team needs policy change.
    """

    AGENT_ROSTER = [
        "po_extraction_agent",
        "hs_validation_agent",
        "doc_generation_agent",
        "compliance_agent",
        "finance_agent",
        "logistics_agent",
        "voice_agent",
        "arabic_agent",
        "supervisor_agent",
    ]

    async def get_workforce_health(self) -> dict:
        health = {}
        for agent_name in self.AGENT_ROSTER:
            # Query workflow_steps table for last 100 steps by this agent
            # Compute: avg_confidence, avg_latency_ms, success_rate, retry_rate
            health[agent_name] = await self._agent_metrics(agent_name)
        return health

    async def auto_tune_prompts(self, agent_name: str, performance: dict):
        """
        If an agent's avg_confidence drops below 80% over 20 runs:
        1. Flag the active prompt version for review
        2. Activate the fallback prompt
        3. Notify admin via dashboard
        4. Create a PromptTester evaluation task
        """
        if performance["avg_confidence"] < 80 and performance["sample_size"] >= 20:
            registry = PromptRegistry
            active   = registry.get(agent_name, "extract_purchase_order")
            registry.deprecate(agent_name, "extract_purchase_order", active.version)
            # Activate fallback
            ...

    async def generate_workforce_report(self) -> str:
        """LLM-generated weekly workforce performance summary."""
        health = await self.get_workforce_health()
        result = await LLMRouter.complete(
            system_prompt="You are a technical operations manager. Summarise AI agent performance for the week.",
            user_prompt=f"Agent metrics:\n{json.dumps(health, indent=2)}",
            max_tokens=600,
        )
        return result["text"]
```

### File: `services/workforce/terminal.py`

```python
class WorkforceTerminal:
    """
    Browser-only AI interface for each employee role.
    No ERP screens. No forms. Just conversation + action buttons.
    Each role gets a custom AI assistant that knows their domain.

    Roles and their terminal personas:
    - operator:   "I handle shipment documentation. Ask me anything about your orders."
    - customs:    "I check compliance. I know DGFT, UAE Customs, Saudi ZATCA."
    - finance:    "I manage invoices and LC documents. I track payments."
    - logistics:  "I track shipments. I predict delays. I book freight."
    - manager:    "I oversee all operations. I approve, escalate, and report."
    """

    ROLE_SYSTEM_PROMPTS = {
        "operator":  "You are a trade documentation expert AI assistant...",
        "customs":   "You are an international trade compliance expert AI assistant...",
        "finance":   "You are a trade finance and accounts AI assistant...",
        "logistics": "You are a freight and logistics AI assistant...",
        "manager":   "You are a senior operations manager AI assistant with full system access...",
    }

    async def chat(self, role: str, user_message: str, conversation_history: list,
                   org_id: str) -> dict:
        # 1. Build system prompt for this role
        # 2. Append relevant memory context
        # 3. Call LLMRouter
        # 4. Parse: did the AI recommend an action (approve, generate, send)?
        # 5. If yes: return action_required=True with action payload for frontend
        ...
```

---

## 3. AI-native export ERP

### Concept

The ERP is not a screen full of forms. It is a conversational interface backed by structured data. The user types or speaks a command; the AI executes it, confirms, and logs everything.

```
User: "Show me all overdue invoices over AED 10,000"
AI:   [queries DB, returns formatted list with direct action buttons]

User: "Send payment reminder to all of them"
AI:   [drafts personalised WhatsApp/email per buyer, shows preview, asks to confirm]

User: "Confirm"
AI:   [sends all reminders, logs in audit_trail, updates invoice status]
```

### File: `services/erp/nl_query_engine.py`

```python
class NLQueryEngine:
    """
    Natural language → structured DB query → formatted response.
    Supports: orders, invoices, shipments, compliance, contacts, analytics.
    Never exposes raw SQL to users.
    """

    async def query(self, user_input: str, org_id: str, role: str) -> dict:
        # Step 1: Intent classification
        intent = await self._classify_intent(user_input)

        # Step 2: Permission check (RBAC)
        require_permission(role, intent["required_permission"])

        # Step 3: Parameter extraction
        params = await self._extract_params(user_input, intent["entity_type"])

        # Step 4: Execute safe DB query (parameterised, never f-string SQL)
        results = await self._execute(intent, params, org_id)

        # Step 5: Format response
        formatted = await self._format_response(results, intent, user_input)

        return {
            "intent":          intent,
            "results":         results,
            "formatted_text":  formatted,
            "suggested_actions": self._suggest_actions(intent, results),
        }

    async def _classify_intent(self, text: str) -> dict:
        result = await LLMRouter.complete(
            system_prompt=(
                "Classify the user's ERP query intent. "
                "Return: entity_type, operation, filters, required_permission."
            ),
            user_prompt=text,
            output_schema={
                "entity_type": "orders|invoices|shipments|contacts|compliance|analytics",
                "operation": "list|get|count|sum|update|send",
                "filters": {},
                "required_permission": "string",
                "confidence": 0
            },
            temperature=0.0,
        )
        return json.loads(result["text"])
```

### File: `services/erp/entity_manager.py`

```python
class EntityManager:
    """
    CRUD operations for all core entities.
    Callable by NLQueryEngine and WorkforceTerminal.
    All operations write to audit_log.
    """

    async def create_contact(self, data: dict, org_id: str, actor: str) -> dict: ...
    async def update_order_status(self, order_id: str, status: str, org_id: str, actor: str) -> dict: ...
    async def bulk_send_payment_reminders(self, invoice_ids: list, org_id: str, actor: str) -> dict: ...
    async def merge_duplicate_contacts(self, contact_ids: list, org_id: str) -> dict: ...
    async def archive_completed_orders(self, before_date: str, org_id: str) -> int: ...
```

### New API endpoints for ERP interface:

```python
@app.post("/api/v1/erp/query")
async def nl_query(body: dict, ctx = Depends(get_org_context)):
    """Natural language query to the ERP."""
    engine = NLQueryEngine()
    return await engine.query(body["query"], str(ctx.org_id), ctx.role)

@app.post("/api/v1/erp/action")
async def erp_action(body: dict, ctx = Depends(get_org_context)):
    """Execute an ERP action confirmed by user."""
    # body: {action_type, entity_ids, params}
    manager = EntityManager()
    return await manager.execute_action(body, str(ctx.org_id), actor=str(ctx.user_id))
```

---

## 4. Multi-company cloud OS

### Concept

A parent company (holding group) has multiple subsidiaries (export companies, subsidiaries in UAE and India). Phase 3 supports this structure natively. One login, cross-entity visibility, consolidated reporting, shared compliance knowledge.

### Schema additions

```sql
-- Add to schemas/002_multicompany.sql

CREATE TABLE org_hierarchy (
    parent_org_id   UUID NOT NULL REFERENCES organizations(id),
    child_org_id    UUID NOT NULL REFERENCES organizations(id),
    relationship    TEXT NOT NULL CHECK (relationship IN ('subsidiary','branch','partner')),
    can_share_data  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (parent_org_id, child_org_id)
);

CREATE TABLE consolidated_reports (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_org_id   UUID NOT NULL REFERENCES organizations(id),
    report_type     TEXT NOT NULL,
    period_start    DATE NOT NULL,
    period_end      DATE NOT NULL,
    data            JSONB NOT NULL,
    generated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE shared_knowledge (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_org_id    UUID NOT NULL REFERENCES organizations(id),
    knowledge_type  TEXT NOT NULL,  -- hs_code | compliance_rule | vendor_profile
    data            JSONB NOT NULL,
    shared_with     UUID[],         -- org_ids that can read this
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### File: `services/multicompany/consolidator.py`

```python
class MultiCompanyConsolidator:
    """
    Consolidates data across subsidiary orgs for group-level reporting.
    Respects data isolation: only parent can request consolidation.
    """

    async def consolidated_revenue(self, parent_org_id: str, period: str) -> dict:
        subsidiaries = await self._get_subsidiaries(parent_org_id)
        revenue_data = []
        for sub_id in subsidiaries:
            sub_revenue = await self._org_revenue(sub_id, period)
            revenue_data.append({"org_id": sub_id, **sub_revenue})
        return {
            "total_revenue":   sum(r["revenue"] for r in revenue_data),
            "by_subsidiary":   revenue_data,
            "currency":        "USD",  # normalized
            "period":          period,
        }

    async def shared_compliance_sync(self, parent_org_id: str):
        """
        When parent's compliance agent learns a new rule,
        propagate to all subsidiaries with can_share_data=True.
        """
        subsidiaries = await self._get_data_sharing_orgs(parent_org_id)
        rules = await self._get_parent_compliance_rules(parent_org_id)
        for sub_id in subsidiaries:
            await self._sync_rules_to_org(sub_id, rules)

    async def group_level_ai_briefing(self, parent_org_id: str) -> str:
        """Group CEO briefing: consolidated view across all entities."""
        data = await self.consolidated_revenue(parent_org_id, "last_30_days")
        result = await LLMRouter.complete(
            system_prompt="You are a group CFO assistant. Write a 5-bullet consolidated operations briefing.",
            user_prompt=f"Group data:\n{json.dumps(data, indent=2)}",
            max_tokens=500,
        )
        return result["text"]
```

### File: `services/multicompany/shared_knowledge_graph.py`

```python
class SharedKnowledgeGraph:
    """
    Compliance rules, HS codes, vendor profiles learned by any org
    can be optionally shared with the group.
    Accelerates new subsidiary onboarding.
    """

    async def contribute(self, org_id: str, knowledge_type: str,
                         data: dict, share_with: list[str]):
        # INSERT INTO shared_knowledge
        ...

    async def query(self, org_id: str, knowledge_type: str, search: str) -> list[dict]:
        # Returns knowledge shared with this org by others in the group
        # Vector similarity search on data::text embedding
        ...
```

---

## 5. Infrastructure upgrades for Phase 3

### Temporal — production-grade workflow execution

Phase 1/2 used the deterministic `WorkflowEngine` locally. Phase 3 requires Temporal for:
- Long-running autonomous workflows (days to weeks)
- Workflow versioning (safe deploys without breaking in-flight workflows)
- Search attributes (query workflows by order_id, org_id, status)
- Schedules (daily briefings, reconciliation runs)

**File:** `services/workflows/temporal_activities.py`

```python
from temporalio import activity, workflow
from temporalio.client import Client
from temporalio.common import RetryPolicy
from datetime import timedelta

@activity.defn
async def extract_po_activity(input: dict) -> dict:
    agent = POExtractionAgent(org_id=uuid.UUID(input["org_id"]))
    return await agent.run(input)

@activity.defn
async def validate_hs_activity(input: dict) -> dict:
    agent = HSCodeValidationAgent(org_id=uuid.UUID(input["org_id"]))
    return await agent.run(input)

# ... one activity per workflow step

@workflow.defn
class POToDispatchWorkflow:
    """Production workflow — replaces WorkflowEngine for Phase 3."""

    @workflow.run
    async def run(self, input: dict) -> dict:
        retry = RetryPolicy(maximum_attempts=3, initial_interval=timedelta(seconds=5))

        extracted = await workflow.execute_activity(
            extract_po_activity, input,
            start_to_close_timeout=timedelta(seconds=60),
            retry_policy=retry,
        )

        hs_result = await workflow.execute_activity(
            validate_hs_activity, {**input, "items": extracted["data"]["items"]},
            start_to_close_timeout=timedelta(seconds=45),
            retry_policy=retry,
        )

        # ... continue steps

        if needs_human:
            # Block until Signal received (days if needed — Temporal persists this)
            await workflow.wait_condition(lambda: self._approved)

        return {"status": "completed", ...}

    @workflow.signal
    async def approval_signal(self, action: str, overrides: dict):
        self._approved = True
        self._approval_action = action

    @workflow.query
    def get_status(self) -> dict:
        return {"current_step": self._current_step, "confidence": self._confidence}
```

### AI auto-reconciliation

```python
# Temporal scheduled workflow — runs nightly
@workflow.defn
class NightlyReconciliationWorkflow:
    """
    Every night:
    1. Match all shipped orders against received payments
    2. Flag unmatched invoices
    3. Update agent_memory with payment patterns
    4. Generate next-day briefing
    5. Archive completed workflows older than 90 days
    """
    @workflow.run
    async def run(self, org_id: str): ...
```

---

## Phase 3 completion checklist

### Autonomous workflows
- [ ] `services/autonomous/policy_engine.py` — dynamic trust-based HITL thresholds
- [ ] `services/autonomous/briefing_engine.py` — daily AI briefing via WhatsApp/email
- [ ] Temporal cron schedule for daily briefing (7 AM org timezone)

### AI workforce orchestration
- [ ] `services/workforce/orchestrator.py` — agent health monitoring + auto-prompt tuning
- [ ] `services/workforce/terminal.py` — browser-only role-specific AI terminals
- [ ] Workforce health API endpoint
- [ ] Weekly workforce performance report

### AI-native ERP
- [ ] `services/erp/nl_query_engine.py` — NL → structured DB query
- [ ] `services/erp/entity_manager.py` — all CRUD with audit logging
- [ ] `/api/v1/erp/query` and `/api/v1/erp/action` endpoints
- [ ] Conversational ERP frontend (Next.js chat interface, no forms)

### Multi-company
- [ ] `schemas/002_multicompany.sql` — org_hierarchy, consolidated_reports, shared_knowledge
- [ ] `services/multicompany/consolidator.py` — cross-entity revenue + compliance sync
- [ ] `services/multicompany/shared_knowledge_graph.py` — group knowledge sharing
- [ ] Group-level RBAC (parent admin can view all subsidiary data)
- [ ] Consolidated reporting API

### Infrastructure
- [ ] `services/workflows/temporal_activities.py` — all workflow steps as Temporal activities
- [ ] `POToDispatchWorkflow` Temporal workflow definition
- [ ] `NightlyReconciliationWorkflow` Temporal scheduled workflow
- [ ] Temporal worker deployment (separate process from FastAPI)
- [ ] Temporal search attributes registered (order_id, org_id, buyer_id, status)

### Long-term vision markers (Phase 3 foundation)
- [ ] `WorkforceTerminal` deployed as standalone browser app (no installed software)
- [ ] Policy configuration UI — owner sets autonomous approval rules, no code change
- [ ] AI workforce hiring UI — admin enables/disables agent roles per org
- [ ] Audit trail exportable as signed PDF for regulatory submissions

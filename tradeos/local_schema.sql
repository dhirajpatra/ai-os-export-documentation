-- ============================================================
-- TradeOS Local — SQLite Schema
-- Runs on customer AI PC (OpenClaw / Ollama setup)
-- ============================================================
--
-- WHAT IS HERE:
--   Everything the local workflow engine needs to run offline.
--   The customer's own data only — orders, contacts, documents,
--   workflows, agent memory, templates, corrections.
--
-- WHAT IS NOT HERE:
--   organizations, users, user_sessions → handled by cloud auth.
--   hs_codes, country_trade_rules       → served by cloud MCP.
--   prompt_registry (global)            → delivered via rules bundle sync.
--   mcp_api_keys, mcp_billing           → cloud only.
--
-- IDENTITY:
--   Every table has org_id (TEXT, fixed per installation) and
--   where relevant user_id (TEXT). Both are set once from env vars
--   at install time: LOCAL_ORG_ID and LOCAL_USER_ID.
--   No foreign key to organizations/users since those tables don't
--   exist locally. Referential integrity is enforced at app layer.
--
-- VECTOR EMBEDDINGS:
--   agent_memory.embedding column is omitted (no pgvector in SQLite).
--   Semantic recall falls back to JSON field matching locally.
--   Full vector search is available via cloud MCP when online.
--
-- SYNC:
--   Tables marked [SYNC UP] push local changes to cloud on sync.
--   Tables marked [SYNC DOWN] receive updates from cloud on sync.
--   Tables marked [LOCAL ONLY] never leave the device.
-- ============================================================

PRAGMA journal_mode = WAL;       -- safe concurrent reads during sync
PRAGMA foreign_keys = ON;
PRAGMA synchronous = NORMAL;     -- good balance of safety and speed


-- ── CONFIG — single row, set at install time ──────────────────────────────────
-- Stores the fixed identity of this installation.
-- Never synced — set once during onboarding.

CREATE TABLE IF NOT EXISTS local_config (
    key     TEXT PRIMARY KEY,
    value   TEXT NOT NULL
);

-- Seed at install:
-- INSERT OR IGNORE INTO local_config VALUES ('org_id',   'uuid-from-tradeos-cloud');
-- INSERT OR IGNORE INTO local_config VALUES ('org_name', 'Agro Exports India Pvt Ltd');
-- INSERT OR IGNORE INTO local_config VALUES ('mcp_key',  'tos_live_...');
-- INSERT OR IGNORE INTO local_config VALUES ('rules_bundle_version', '0.0.0');
-- INSERT OR IGNORE INTO local_config VALUES ('last_synced_at', '');


-- ── 1. CONTACTS [SYNC UP] ─────────────────────────────────────────────────────
-- Buyer and supplier profiles learned locally.
-- Pushed to cloud on sync so cloud has the full contact graph.

CREATE TABLE IF NOT EXISTS contacts (
    id              TEXT PRIMARY KEY,               -- UUID as text
    org_id          TEXT NOT NULL,
    type            TEXT NOT NULL
                        CHECK (type IN ('buyer','supplier','freight',
                                        'customs_broker','bank')),
    name            TEXT NOT NULL,
    country         TEXT,                           -- ISO-2
    currency        TEXT,
    payment_terms   TEXT,
    whatsapp        TEXT,
    email           TEXT,
    address         TEXT,                           -- JSON string
    bank_details    TEXT,                           -- JSON string, encrypted at app layer
    custom_fields   TEXT NOT NULL DEFAULT '{}',    -- JSON string
    ai_notes        TEXT,
    preferred_doc_format TEXT,
    avg_order_value REAL,
    risk_score      INTEGER CHECK (risk_score BETWEEN 0 AND 100),
    synced_at       TEXT,                           -- ISO timestamp, NULL = not yet synced
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_contacts_org ON contacts(org_id);
CREATE INDEX IF NOT EXISTS idx_contacts_unsynced ON contacts(org_id, synced_at)
    WHERE synced_at IS NULL;


-- ── 2. PRODUCTS [SYNC UP] ─────────────────────────────────────────────────────
-- Customer's product catalogue with learned HS codes.

CREATE TABLE IF NOT EXISTS products (
    id                  TEXT PRIMARY KEY,
    org_id              TEXT NOT NULL,
    sku                 TEXT NOT NULL,
    description         TEXT NOT NULL,
    hs_code             TEXT,
    hs_validated_at     TEXT,
    hs_confidence       REAL,
    unit                TEXT NOT NULL DEFAULT 'KG',
    default_currency    TEXT NOT NULL DEFAULT 'USD',
    unit_price          REAL,
    country_of_origin   TEXT,
    custom_fields       TEXT NOT NULL DEFAULT '{}',
    synced_at           TEXT,
    created_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_products_org_sku ON products(org_id, sku);


-- ── 3. ORDERS [SYNC UP] ──────────────────────────────────────────────────────
-- Core shipment records. Created locally, pushed to cloud.

CREATE TABLE IF NOT EXISTS orders (
    id                  TEXT PRIMARY KEY,
    org_id              TEXT NOT NULL,
    order_number        TEXT NOT NULL,
    buyer_id            TEXT REFERENCES contacts(id),
    status              TEXT NOT NULL DEFAULT 'draft'
                            CHECK (status IN (
                                'draft','po_received','documents_pending',
                                'compliance_check','awaiting_approval',
                                'approved','dispatched','in_transit',
                                'delivered','cancelled'
                            )),
    currency            TEXT NOT NULL DEFAULT 'USD',
    total_amount        REAL,
    payment_terms       TEXT,
    incoterms           TEXT,
    port_of_loading     TEXT,
    port_of_discharge   TEXT,
    destination_country TEXT,
    po_source           TEXT CHECK (po_source IN ('whatsapp','email','portal','manual')),
    po_raw_text         TEXT,                       -- original PO text, kept locally
    po_file_path        TEXT,                       -- local file path (not S3)
    workflow_id         TEXT,
    notes               TEXT,
    extracted_data      TEXT,                       -- JSON string of last extraction result
    synced_at           TEXT,
    created_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    UNIQUE (org_id, order_number)
);

CREATE INDEX IF NOT EXISTS idx_orders_org_status ON orders(org_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_unsynced ON orders(org_id, synced_at)
    WHERE synced_at IS NULL;


CREATE TABLE IF NOT EXISTS order_items (
    id              TEXT PRIMARY KEY,
    order_id        TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id      TEXT REFERENCES products(id),
    description     TEXT NOT NULL,
    hs_code         TEXT,
    quantity        REAL NOT NULL,
    unit            TEXT NOT NULL,
    unit_price      REAL NOT NULL,
    discount_pct    REAL DEFAULT 0,
    total_price     REAL,                           -- computed at app layer
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);


-- ── 4. DOCUMENTS [LOCAL ONLY — metadata synced up] ───────────────────────────
-- Generated document metadata. File bytes stay on local disk.
-- Only metadata (not file content) is synced to cloud.

CREATE TABLE IF NOT EXISTS documents (
    id                  TEXT PRIMARY KEY,
    org_id              TEXT NOT NULL,
    order_id            TEXT REFERENCES orders(id),
    doc_type            TEXT NOT NULL
                            CHECK (doc_type IN (
                                'purchase_order','commercial_invoice','packing_list',
                                'certificate_of_origin','shipping_bill','bill_of_lading',
                                'airway_bill','lc_document','insurance_certificate',
                                'fumigation_certificate','phytosanitary','gsp_certificate',
                                'customs_declaration','delivery_note','other'
                            )),
    reference_number    TEXT,
    status              TEXT NOT NULL DEFAULT 'draft'
                            CHECK (status IN ('draft','pending_review','approved',
                                              'rejected','sent','archived')),
    version             INTEGER NOT NULL DEFAULT 1,
    parent_version_id   TEXT REFERENCES documents(id),
    local_file_path     TEXT,                       -- path on local disk
    file_size_bytes     INTEGER,
    mime_type           TEXT,
    checksum            TEXT,
    generated_by        TEXT,                       -- agent name
    ai_confidence       REAL,
    extracted_data      TEXT,                       -- JSON string
    reviewed_at         TEXT,
    review_notes        TEXT,
    synced_at           TEXT,                       -- metadata sync timestamp
    created_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_documents_org_order ON documents(org_id, order_id);


-- ── 5. WORKFLOWS [LOCAL ONLY] ────────────────────────────────────────────────
-- Workflow execution state. Fully local — cloud doesn't need to know
-- the internal saga steps, only the final order outcome.

CREATE TABLE IF NOT EXISTS workflows (
    id              TEXT PRIMARY KEY,
    org_id          TEXT NOT NULL,
    order_id        TEXT REFERENCES orders(id),
    name            TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'running'
                        CHECK (status IN ('running','paused','awaiting_human',
                                          'completed','failed','compensating')),
    current_step    TEXT,
    state_snapshot  TEXT NOT NULL DEFAULT '{}',     -- JSON string
    context         TEXT NOT NULL DEFAULT '{}',     -- JSON string
    started_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    completed_at    TEXT,
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE TABLE IF NOT EXISTS workflow_steps (
    id              TEXT PRIMARY KEY,
    workflow_id     TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
    step_name       TEXT NOT NULL,
    agent_name      TEXT,
    status          TEXT NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','running','completed',
                                          'failed','skipped','compensated')),
    input           TEXT,                           -- JSON string
    output          TEXT,                           -- JSON string
    error           TEXT,                           -- JSON string
    ai_confidence   REAL,
    tokens_used     INTEGER,
    latency_ms      INTEGER,
    retry_count     INTEGER NOT NULL DEFAULT 0,
    started_at      TEXT,
    completed_at    TEXT,
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_workflow_steps_workflow ON workflow_steps(workflow_id);


-- ── 6. HITL — APPROVALS [SYNC UP] ────────────────────────────────────────────
-- Human review queue. Approval decisions sync to cloud so the
-- cloud has a complete audit trail of what was approved and when.

CREATE TABLE IF NOT EXISTS approval_requests (
    id              TEXT PRIMARY KEY,
    org_id          TEXT NOT NULL,
    workflow_id     TEXT NOT NULL REFERENCES workflows(id),
    workflow_step_id TEXT REFERENCES workflow_steps(id),
    order_id        TEXT REFERENCES orders(id),
    document_id     TEXT REFERENCES documents(id),
    requested_by    TEXT NOT NULL,                  -- agent name
    title           TEXT NOT NULL,
    description     TEXT,
    ai_confidence   REAL NOT NULL,
    risk_flags      TEXT NOT NULL DEFAULT '[]',     -- JSON string
    suggested_action TEXT,
    diff_before     TEXT,                           -- JSON string
    diff_after      TEXT,                           -- JSON string
    status          TEXT NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','approved','rejected','expired')),
    reviewed_at     TEXT,
    review_note     TEXT,
    field_overrides TEXT DEFAULT '{}',              -- JSON: what human changed
    expires_at      TEXT,
    synced_at       TEXT,
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_approvals_org_status ON approval_requests(org_id, status);


-- ── 7. HITL CORRECTIONS [SYNC UP] ────────────────────────────────────────────
-- Field-level corrections from HITL review.
-- THIS IS THE MOST IMPORTANT SYNC-UP TABLE.
-- Cloud aggregates these across orgs to improve global HS and template quality.

CREATE TABLE IF NOT EXISTS hitl_corrections (
    id              TEXT PRIMARY KEY,
    org_id          TEXT NOT NULL,
    workflow_id     TEXT NOT NULL,
    order_id        TEXT,
    buyer_key       TEXT,
    field_name      TEXT NOT NULL,
    wrong_value     TEXT,
    correct_value   TEXT NOT NULL,
    correction_source TEXT NOT NULL DEFAULT 'hitl_approval',
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    synced_at       TEXT                            -- NULL = not yet pushed to cloud
);

CREATE INDEX IF NOT EXISTS idx_hitl_corrections_org_buyer
    ON hitl_corrections(org_id, buyer_key);
CREATE INDEX IF NOT EXISTS idx_hitl_corrections_unsynced
    ON hitl_corrections(org_id, synced_at)
    WHERE synced_at IS NULL;


-- ── 8. AUDIT LOG [LOCAL ONLY] ────────────────────────────────────────────────
-- Local action log. Stays on device for privacy.
-- Cloud gets only approval decisions, not every agent action.

CREATE TABLE IF NOT EXISTS audit_log (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    org_id          TEXT NOT NULL,
    actor_type      TEXT NOT NULL CHECK (actor_type IN ('user','agent','system')),
    actor_id        TEXT NOT NULL,
    action          TEXT NOT NULL,
    entity_type     TEXT NOT NULL,
    entity_id       TEXT NOT NULL,
    old_value       TEXT,                           -- JSON string
    new_value       TEXT,                           -- JSON string
    metadata        TEXT NOT NULL DEFAULT '{}',
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_audit_org_entity
    ON audit_log(org_id, entity_type, entity_id);


-- ── 9. AGENT MEMORY [SYNC UP — without embeddings] ───────────────────────────
-- Local operational memory: buyer preferences, shipment patterns,
-- learned HS codes, invoice styles.
-- Embeddings column removed — no pgvector in SQLite.
-- Similarity recall uses JSON field matching locally.
-- Full vector search available via cloud MCP when online.
-- Synced to cloud so the cloud memory layer stays current.

CREATE TABLE IF NOT EXISTS agent_memory (
    id                  TEXT PRIMARY KEY,
    org_id              TEXT NOT NULL,
    agent_name          TEXT NOT NULL,
    memory_type         TEXT NOT NULL
                            CHECK (memory_type IN (
                                'customer_preference','shipment_pattern','hs_code_learned',
                                'vendor_behavior','invoice_style','country_rule',
                                'workflow_shortcut','risk_pattern','seasonal_pattern'
                            )),
    scope_type          TEXT NOT NULL CHECK (scope_type IN ('org','contact','product','route')),
    scope_id            TEXT,
    key                 TEXT NOT NULL,
    value               TEXT NOT NULL,              -- JSON string
    confidence          REAL NOT NULL DEFAULT 50,
    source              TEXT,
    observation_count   INTEGER NOT NULL DEFAULT 1,
    last_observed_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    expires_at          TEXT,
    synced_at           TEXT,
    created_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_memory_org_agent
    ON agent_memory(org_id, agent_name, memory_type);
CREATE INDEX IF NOT EXISTS idx_memory_scope
    ON agent_memory(scope_type, scope_id);
CREATE INDEX IF NOT EXISTS idx_memory_unsynced
    ON agent_memory(org_id, synced_at)
    WHERE synced_at IS NULL;


-- ── 10. PO TEMPLATES [SYNC DOWN + SYNC UP] ───────────────────────────────────
-- Buyer-specific learned extraction templates.
-- LOCAL WRITE: templates are learned from local extractions and corrections.
-- SYNC UP: push updated templates to cloud so cloud HS MCP can use them.
-- SYNC DOWN: cloud may push improved templates back (after cross-org learning).
-- This is the table where the per-org intelligence lives.

CREATE TABLE IF NOT EXISTS po_templates (
    id                          TEXT PRIMARY KEY,
    org_id                      TEXT NOT NULL,
    buyer_key                   TEXT NOT NULL,
    buyer_name                  TEXT,
    buyer_country               TEXT,
    currency                    TEXT,
    payment_terms               TEXT,
    incoterms                   TEXT,
    destination_port            TEXT,
    field_anchors               TEXT NOT NULL DEFAULT '[]',  -- JSON string
    use_count                   INTEGER NOT NULL DEFAULT 1,
    avg_confidence              REAL NOT NULL DEFAULT 80.0,
    last_extraction_confidence  REAL,
    llm_fallback_count          INTEGER NOT NULL DEFAULT 0,
    template_hit_count          INTEGER NOT NULL DEFAULT 0,
    last_used_at                TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    synced_at                   TEXT,
    created_at                  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at                  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    UNIQUE (org_id, buyer_key)
);

CREATE INDEX IF NOT EXISTS idx_po_templates_org_buyer
    ON po_templates(org_id, buyer_key);
CREATE INDEX IF NOT EXISTS idx_po_templates_unsynced
    ON po_templates(org_id, synced_at)
    WHERE synced_at IS NULL;


-- ── 11. PROMPT REGISTRY [SYNC DOWN ONLY] ─────────────────────────────────────
-- Prompts delivered from cloud via rules bundle sync.
-- LOCAL AGENTS READ from this. Never write to it locally.
-- Updated automatically when a new rules bundle is applied.
-- org_id NULL = global prompt, org_id set = org-specific override.

CREATE TABLE IF NOT EXISTS prompt_registry (
    id              TEXT PRIMARY KEY,
    org_id          TEXT,                           -- NULL = global
    agent_name      TEXT NOT NULL,
    prompt_key      TEXT NOT NULL,
    version         INTEGER NOT NULL DEFAULT 1,
    is_active       INTEGER NOT NULL DEFAULT 1,     -- SQLite has no BOOLEAN
    system_prompt   TEXT NOT NULL,
    user_template   TEXT NOT NULL,
    output_schema   TEXT,                           -- JSON string
    fallback_model  TEXT,
    avg_confidence  REAL,
    success_count   INTEGER NOT NULL DEFAULT 0,
    failure_count   INTEGER NOT NULL DEFAULT 0,
    avg_latency_ms  INTEGER,
    bundle_version  TEXT,                           -- which rules bundle this came from
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_prompt_agent_key_version
    ON prompt_registry(agent_name, prompt_key, version);
CREATE INDEX IF NOT EXISTS idx_prompt_active
    ON prompt_registry(agent_name, prompt_key, is_active);


-- ── 12. MESSAGES [SYNC UP — metadata only] ───────────────────────────────────
-- Inbound WhatsApp/email messages that triggered workflows.
-- Body text stays local. Metadata (intent, order_id) synced to cloud.

CREATE TABLE IF NOT EXISTS messages (
    id              TEXT PRIMARY KEY,
    org_id          TEXT NOT NULL,
    order_id        TEXT REFERENCES orders(id),
    contact_id      TEXT REFERENCES contacts(id),
    channel         TEXT NOT NULL CHECK (channel IN ('whatsapp','email','sms','portal')),
    direction       TEXT NOT NULL CHECK (direction IN ('inbound','outbound')),
    from_address    TEXT,
    to_address      TEXT,
    subject         TEXT,
    body            TEXT,                           -- stays local
    body_lang       TEXT,
    intent          TEXT,
    extracted_data  TEXT,                           -- JSON string
    ai_processed    INTEGER NOT NULL DEFAULT 0,
    status          TEXT NOT NULL DEFAULT 'received'
                        CHECK (status IN ('received','processing','processed',
                                          'sent','delivered','failed')),
    external_id     TEXT,
    synced_at       TEXT,
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_messages_org_order ON messages(org_id, order_id);


-- ── 13. SHIPMENTS [SYNC UP] ───────────────────────────────────────────────────
-- Shipment tracking records.

CREATE TABLE IF NOT EXISTS shipments (
    id                  TEXT PRIMARY KEY,
    org_id              TEXT NOT NULL,
    order_id            TEXT NOT NULL REFERENCES orders(id),
    carrier             TEXT,
    service_type        TEXT,
    tracking_number     TEXT,
    bl_number           TEXT,
    vessel_name         TEXT,
    port_of_loading     TEXT,
    port_of_discharge   TEXT,
    etd                 TEXT,
    eta                 TEXT,
    actual_departure    TEXT,
    actual_arrival      TEXT,
    status              TEXT NOT NULL DEFAULT 'booking_pending',
    last_event          TEXT,
    last_event_at       TEXT,
    synced_at           TEXT,
    created_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);


-- ── 14. LOGISTICS VENDORS [SYNC DOWN] ────────────────────────────────────────
-- Freight vendor profiles. Delivered from cloud — customer doesn't
-- manually manage this, TradeOS maintains it.

CREATE TABLE IF NOT EXISTS logistics_vendors (
    id              TEXT PRIMARY KEY,
    org_id          TEXT NOT NULL,
    name            TEXT NOT NULL,
    country         TEXT,
    supported_ports TEXT,                           -- JSON array string
    contact_info    TEXT,                           -- JSON string
    services        TEXT,                           -- JSON array string
    bundle_version  TEXT,
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);


-- ── TRIGGERS — auto-update updated_at ────────────────────────────────────────

CREATE TRIGGER IF NOT EXISTS trg_contacts_updated_at
    AFTER UPDATE ON contacts FOR EACH ROW
    BEGIN UPDATE contacts SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now')
          WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_orders_updated_at
    AFTER UPDATE ON orders FOR EACH ROW
    BEGIN UPDATE orders SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now')
          WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_documents_updated_at
    AFTER UPDATE ON documents FOR EACH ROW
    BEGIN UPDATE documents SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now')
          WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_agent_memory_updated_at
    AFTER UPDATE ON agent_memory FOR EACH ROW
    BEGIN UPDATE agent_memory SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now')
          WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_po_templates_updated_at
    AFTER UPDATE ON po_templates FOR EACH ROW
    BEGIN UPDATE po_templates SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now')
          WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_shipments_updated_at
    AFTER UPDATE ON shipments FOR EACH ROW
    BEGIN UPDATE shipments SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now')
          WHERE id = NEW.id; END;

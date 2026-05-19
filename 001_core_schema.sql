-- ============================================================
-- TradeOS — Core Database Schema
-- Multi-tenant · Agent Memory · Workflow State · Audit Trail
-- ============================================================

-- ─── Extensions ───────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "vector";          -- pgvector for agent memory

-- ─── 1. TENANCY ───────────────────────────────────────────

CREATE TABLE organizations (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            TEXT NOT NULL,
    slug            TEXT UNIQUE NOT NULL,
    country         CHAR(2) NOT NULL DEFAULT 'IN',    -- ISO 3166
    iec_code        TEXT,                              -- India IEC / Trade license
    gstin           TEXT,
    vat_number      TEXT,                              -- GCC VAT
    plan            TEXT NOT NULL DEFAULT 'starter'   -- starter | growth | enterprise
                        CHECK (plan IN ('starter','growth','enterprise')),
    timezone        TEXT NOT NULL DEFAULT 'Asia/Kolkata',
    default_currency CHAR(3) NOT NULL DEFAULT 'INR',
    whatsapp_number TEXT,
    smtp_config     JSONB,                             -- encrypted at app layer
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    email           TEXT NOT NULL,
    name            TEXT NOT NULL,
    role            TEXT NOT NULL DEFAULT 'operator'
                        CHECK (role IN ('owner','admin','manager','operator','viewer')),
    password_hash   TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    last_login_at   TIMESTAMPTZ,
    preferences     JSONB NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (org_id, email)
);

CREATE INDEX idx_users_org ON users(org_id);

-- ─── 2. CONTACTS (Buyers / Suppliers) ──────────────────────

CREATE TABLE contacts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    type            TEXT NOT NULL CHECK (type IN ('buyer','supplier','freight','customs_broker','bank')),
    name            TEXT NOT NULL,
    country         CHAR(2),
    currency        CHAR(3),
    payment_terms   TEXT,                              -- LC | TT | DA | DP
    whatsapp        TEXT,
    email           TEXT,
    address         JSONB,
    bank_details    JSONB,                             -- encrypted at app layer
    custom_fields   JSONB NOT NULL DEFAULT '{}',
    -- AI-learned preferences (populated by Memory Layer)
    ai_notes        TEXT,
    preferred_doc_format TEXT,
    avg_order_value NUMERIC(14,2),
    risk_score      SMALLINT CHECK (risk_score BETWEEN 0 AND 100),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_contacts_org ON contacts(org_id);

-- ─── 3. PRODUCTS / SKUs ───────────────────────────────────

CREATE TABLE products (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    sku             TEXT NOT NULL,
    description     TEXT NOT NULL,
    hs_code         TEXT,
    hs_validated_at TIMESTAMPTZ,
    hs_confidence   NUMERIC(5,2),                     -- AI confidence 0-100
    unit            TEXT NOT NULL DEFAULT 'KG',
    default_currency CHAR(3) NOT NULL DEFAULT 'USD',
    unit_price      NUMERIC(14,4),
    country_of_origin CHAR(2),
    custom_fields   JSONB NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_products_org_sku ON products(org_id, sku);

-- ─── 4. ORDERS ────────────────────────────────────────────

CREATE TABLE orders (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    order_number    TEXT NOT NULL,
    buyer_id        UUID NOT NULL REFERENCES contacts(id),
    status          TEXT NOT NULL DEFAULT 'draft'
                        CHECK (status IN (
                            'draft','po_received','documents_pending',
                            'compliance_check','awaiting_approval',
                            'approved','dispatched','in_transit',
                            'delivered','cancelled'
                        )),
    currency        CHAR(3) NOT NULL DEFAULT 'USD',
    total_amount    NUMERIC(14,2),
    payment_terms   TEXT,
    incoterms       TEXT,                              -- FOB | CIF | EXW
    port_of_loading TEXT,
    port_of_discharge TEXT,
    destination_country CHAR(2),
    -- Source of the PO
    po_source       TEXT CHECK (po_source IN ('whatsapp','email','portal','manual')),
    po_raw_text     TEXT,                              -- original extracted text
    po_file_id      UUID,                              -- references documents
    -- Workflow
    workflow_id     UUID,
    assigned_to     UUID REFERENCES users(id),
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (org_id, order_number)
);

CREATE TABLE order_items (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id        UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id      UUID REFERENCES products(id),
    description     TEXT NOT NULL,
    hs_code         TEXT,
    quantity        NUMERIC(14,4) NOT NULL,
    unit            TEXT NOT NULL,
    unit_price      NUMERIC(14,4) NOT NULL,
    discount_pct    NUMERIC(5,2) DEFAULT 0,
    total_price     NUMERIC(14,2) GENERATED ALWAYS AS
                        (ROUND(quantity * unit_price * (1 - COALESCE(discount_pct,0)/100), 2)) STORED
);

-- ─── 5. DOCUMENTS ─────────────────────────────────────────

CREATE TABLE documents (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    order_id        UUID REFERENCES orders(id),
    doc_type        TEXT NOT NULL
                        CHECK (doc_type IN (
                            'purchase_order','commercial_invoice','packing_list',
                            'certificate_of_origin','shipping_bill','bill_of_lading',
                            'airway_bill','lc_document','insurance_certificate',
                            'fumigation_certificate','phytosanitary','gsp_certificate',
                            'customs_declaration','delivery_note','other'
                        )),
    reference_number TEXT,
    status          TEXT NOT NULL DEFAULT 'draft'
                        CHECK (status IN ('draft','pending_review','approved','rejected','sent','archived')),
    version         INTEGER NOT NULL DEFAULT 1,
    parent_version_id UUID REFERENCES documents(id),   -- for rollback
    -- File storage
    storage_path    TEXT,                              -- S3 / GCS path
    file_size_bytes INTEGER,
    mime_type       TEXT,
    checksum        TEXT,
    -- AI generation metadata
    generated_by    TEXT,                              -- agent name
    ai_confidence   NUMERIC(5,2),
    generation_prompt_id UUID,                         -- references prompt_registry
    extracted_data  JSONB,                             -- structured extraction result
    -- Human review
    reviewed_by     UUID REFERENCES users(id),
    reviewed_at     TIMESTAMPTZ,
    review_notes    TEXT,
    -- Timestamps
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_documents_org_order ON documents(org_id, order_id);
CREATE INDEX idx_documents_type_status ON documents(doc_type, status);

-- ─── 6. WORKFLOWS ─────────────────────────────────────────

CREATE TABLE workflows (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    order_id        UUID REFERENCES orders(id),
    name            TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'running'
                        CHECK (status IN ('running','paused','awaiting_human','completed','failed','compensating')),
    current_step    TEXT,
    -- Temporal workflow correlation
    temporal_workflow_id TEXT,
    temporal_run_id TEXT,
    -- State snapshot (for deterministic replay)
    state_snapshot  JSONB NOT NULL DEFAULT '{}',
    context         JSONB NOT NULL DEFAULT '{}',
    -- Timing
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at    TIMESTAMPTZ,
    timeout_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE workflow_steps (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workflow_id     UUID NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
    step_name       TEXT NOT NULL,
    agent_name      TEXT,
    status          TEXT NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','running','completed','failed','skipped','compensated')),
    input           JSONB,
    output          JSONB,
    error           JSONB,
    ai_confidence   NUMERIC(5,2),
    tokens_used     INTEGER,
    latency_ms      INTEGER,
    retry_count     SMALLINT NOT NULL DEFAULT 0,
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_workflow_steps_workflow ON workflow_steps(workflow_id);

-- ─── 7. HITL — HUMAN IN THE LOOP ──────────────────────────

CREATE TABLE approval_requests (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    workflow_id     UUID NOT NULL REFERENCES workflows(id),
    workflow_step_id UUID REFERENCES workflow_steps(id),
    order_id        UUID REFERENCES orders(id),
    document_id     UUID REFERENCES documents(id),
    requested_by    TEXT NOT NULL,                     -- agent name
    title           TEXT NOT NULL,
    description     TEXT,
    -- Risk context
    ai_confidence   NUMERIC(5,2) NOT NULL,
    risk_flags      JSONB NOT NULL DEFAULT '[]',       -- list of flag objects
    suggested_action TEXT,
    -- What changed (diff)
    diff_before     JSONB,
    diff_after      JSONB,
    -- Review
    status          TEXT NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','approved','rejected','expired')),
    assigned_to     UUID REFERENCES users(id),
    reviewed_by     UUID REFERENCES users(id),
    reviewed_at     TIMESTAMPTZ,
    review_note     TEXT,
    expires_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_approvals_org_status ON approval_requests(org_id, status);
CREATE INDEX idx_approvals_assigned ON approval_requests(assigned_to, status);

-- ─── 8. AUDIT TRAIL ───────────────────────────────────────

CREATE TABLE audit_log (
    id              BIGSERIAL PRIMARY KEY,
    org_id          UUID NOT NULL,
    actor_type      TEXT NOT NULL CHECK (actor_type IN ('user','agent','system')),
    actor_id        TEXT NOT NULL,                     -- user UUID or agent name
    action          TEXT NOT NULL,
    entity_type     TEXT NOT NULL,
    entity_id       TEXT NOT NULL,
    old_value       JSONB,
    new_value       JSONB,
    metadata        JSONB NOT NULL DEFAULT '{}',
    ip_address      INET,
    user_agent      TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (created_at);

-- Monthly partitions
CREATE TABLE audit_log_2025_01 PARTITION OF audit_log
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE audit_log_2025_02 PARTITION OF audit_log
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE audit_log_2025_03 PARTITION OF audit_log
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
CREATE TABLE audit_log_default  PARTITION OF audit_log DEFAULT;

CREATE INDEX idx_audit_org_entity ON audit_log(org_id, entity_type, entity_id);

-- ─── 9. AGENT MEMORY ──────────────────────────────────────

CREATE TABLE agent_memory (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    agent_name      TEXT NOT NULL,
    memory_type     TEXT NOT NULL
                        CHECK (memory_type IN (
                            'customer_preference','shipment_pattern','hs_code_learned',
                            'vendor_behavior','invoice_style','country_rule',
                            'workflow_shortcut','risk_pattern','seasonal_pattern'
                        )),
    scope_type      TEXT NOT NULL CHECK (scope_type IN ('org','contact','product','route')),
    scope_id        UUID,                              -- contact_id / product_id etc.
    key             TEXT NOT NULL,
    value           JSONB NOT NULL,
    confidence      NUMERIC(5,2) NOT NULL DEFAULT 50,
    source          TEXT,                              -- 'observation' | 'feedback' | 'inference'
    observation_count INTEGER NOT NULL DEFAULT 1,
    last_observed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ,
    embedding       vector(1536),                      -- for similarity search
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_memory_org_agent ON agent_memory(org_id, agent_name, memory_type);
CREATE INDEX idx_memory_scope ON agent_memory(scope_type, scope_id);
CREATE INDEX idx_memory_embedding ON agent_memory USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);

-- ─── 10. PROMPT REGISTRY ──────────────────────────────────

CREATE TABLE prompt_registry (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID,                              -- NULL = global
    agent_name      TEXT NOT NULL,
    prompt_key      TEXT NOT NULL,
    version         INTEGER NOT NULL DEFAULT 1,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    system_prompt   TEXT NOT NULL,
    user_template   TEXT NOT NULL,
    output_schema   JSONB,                             -- JSON Schema for expected output
    -- Fallback chain
    fallback_model  TEXT,
    fallback_prompt_id UUID REFERENCES prompt_registry(id),
    -- Performance tracking
    avg_confidence  NUMERIC(5,2),
    success_count   INTEGER NOT NULL DEFAULT 0,
    failure_count   INTEGER NOT NULL DEFAULT 0,
    avg_latency_ms  INTEGER,
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_prompt_agent_key_version
    ON prompt_registry(agent_name, prompt_key, version);
CREATE INDEX idx_prompt_active ON prompt_registry(agent_name, prompt_key, is_active);

-- ─── 11. COMMUNICATIONS ───────────────────────────────────

CREATE TABLE messages (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    order_id        UUID REFERENCES orders(id),
    contact_id      UUID REFERENCES contacts(id),
    channel         TEXT NOT NULL CHECK (channel IN ('whatsapp','email','sms','portal')),
    direction       TEXT NOT NULL CHECK (direction IN ('inbound','outbound')),
    from_address    TEXT,
    to_address      TEXT,
    subject         TEXT,
    body            TEXT,
    body_lang       CHAR(2),                           -- detected language
    body_translated TEXT,                              -- if translation applied
    attachments     JSONB NOT NULL DEFAULT '[]',
    -- AI extraction
    intent          TEXT,
    extracted_data  JSONB,
    ai_processed    BOOLEAN NOT NULL DEFAULT FALSE,
    -- Status
    status          TEXT NOT NULL DEFAULT 'received'
                        CHECK (status IN ('received','processing','processed','sent','delivered','failed')),
    external_id     TEXT,                              -- WhatsApp message ID
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_messages_org_order ON messages(org_id, order_id);
CREATE INDEX idx_messages_contact ON messages(contact_id, created_at DESC);

-- ─── 12. SHIPMENTS ────────────────────────────────────────

CREATE TABLE shipments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    order_id        UUID NOT NULL REFERENCES orders(id),
    carrier         TEXT,
    service_type    TEXT,                              -- sea | air | road | courier
    tracking_number TEXT,
    bl_number       TEXT,
    awb_number      TEXT,
    container_number TEXT,
    vessel_name     TEXT,
    voyage_number   TEXT,
    port_of_loading TEXT,
    port_of_discharge TEXT,
    etd             DATE,
    eta             DATE,
    actual_departure TIMESTAMPTZ,
    actual_arrival  TIMESTAMPTZ,
    status          TEXT NOT NULL DEFAULT 'booking_pending'
                        CHECK (status IN (
                            'booking_pending','booked','cargo_received',
                            'customs_cleared','laden_on_vessel','in_transit',
                            'arrived','customs_hold','delivered'
                        )),
    last_event      TEXT,
    last_event_at   TIMESTAMPTZ,
    carrier_raw_response JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE shipment_events (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shipment_id     UUID NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
    event_code      TEXT NOT NULL,
    description     TEXT NOT NULL,
    location        TEXT,
    occurred_at     TIMESTAMPTZ NOT NULL,
    source          TEXT,                              -- carrier | manual | customs
    raw_data        JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── 13. COMPLIANCE KB ────────────────────────────────────

CREATE TABLE hs_codes (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code            TEXT NOT NULL UNIQUE,
    description     TEXT NOT NULL,
    chapter         TEXT,
    parent_code     TEXT,
    notes           TEXT,
    embedding       vector(1536),                      -- semantic search
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE country_trade_rules (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    from_country    CHAR(2) NOT NULL,
    to_country      CHAR(2) NOT NULL,
    hs_code_prefix  TEXT,                              -- NULL = applies to all
    rule_type       TEXT NOT NULL
                        CHECK (rule_type IN ('import_duty','export_restriction','banned',
                                             'permit_required','quota','vat','gst','preference')),
    rule_value      JSONB NOT NULL,
    source          TEXT,                              -- DGFT | UAE Customs | etc.
    effective_from  DATE,
    effective_to    DATE,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_country_rules_route ON country_trade_rules(from_country, to_country);

-- ─── Helper: auto-updated timestamps ──────────────────────

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;

DO $$ DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['organizations','users','contacts','products',
                            'orders','documents','agent_memory','shipments'] LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_%I_updated_at BEFORE UPDATE ON %I
       FOR EACH ROW EXECUTE FUNCTION set_updated_at()', t, t);
  END LOOP;
END $$;

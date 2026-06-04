-- Org-level API keys for MCP authentication
-- One key per org, scoped to their plan
CREATE TABLE mcp_api_keys (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    key_hash        TEXT NOT NULL UNIQUE,   -- SHA-256 of the raw key, never store raw
    key_prefix      TEXT NOT NULL,          -- first 8 chars for display: "tos_live_ab12cd34..."
    environment     TEXT NOT NULL DEFAULT 'live' CHECK (environment IN ('live','test')),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    last_used_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_mcp_api_keys_org_env UNIQUE (org_id, environment)
);

-- MCP service call log — used for billing and quota enforcement
CREATE TABLE mcp_usage_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    service         TEXT NOT NULL,          -- "hs_classification" | "freight" | "compliance"
    action          TEXT NOT NULL,          -- "validate" | "classify" | "rate_lookup"
    request_ms      INT,                    -- latency
    tokens_used     INT DEFAULT 0,
    cost_usd        NUMERIC(10,6) DEFAULT 0,
    status          TEXT NOT NULL DEFAULT 'ok' CHECK (status IN ('ok','error','quota_exceeded')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_mcp_usage_org_month ON mcp_usage_log (org_id, date_trunc('month', created_at AT TIME ZONE 'UTC'));

-- Monthly quota and billing state per org
CREATE TABLE mcp_billing (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    period_start    DATE NOT NULL,
    period_end      DATE NOT NULL,
    plan            TEXT NOT NULL,          -- copied from org plan at period start
    calls_used      INT NOT NULL DEFAULT 0,
    calls_limit     INT NOT NULL,           -- set by plan: starter=100, growth=1000, enterprise=-1
    cost_usd        NUMERIC(10,4) DEFAULT 0,
    is_paid         BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_mcp_billing_org_period UNIQUE (org_id, period_start)
);

-- Tracks which rules bundle version the org is currently on
ALTER TABLE organizations
    ADD COLUMN IF NOT EXISTS rules_bundle_version  TEXT    NOT NULL DEFAULT '0.0.0',
    ADD COLUMN IF NOT EXISTS rules_bundle_synced_at TIMESTAMPTZ;
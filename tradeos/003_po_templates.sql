-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: 003_po_templates.sql
-- Creates the po_templates table for buyer-specific PO template learning.
-- Run after 001_core_schema.sql and 002_alter_embedding_dim.sql
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS po_templates (
    id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id           UUID        NOT NULL,   -- tenant isolation
    buyer_key        TEXT        NOT NULL,   -- normalised slug e.g. "al_rashid_trading"
    buyer_name       TEXT,                   -- display name
    buyer_country    CHAR(2),               -- ISO-3166 e.g. "AE"

    -- Stable commercial fields learned from past extractions
    currency         VARCHAR(5),            -- "USD", "AED" etc.
    payment_terms    TEXT,                  -- "LC", "TT", "CAD" etc.
    incoterms        VARCHAR(10),           -- "CIF", "FOB" etc.
    destination_port TEXT,                  -- "Jebel Ali", "Jeddah" etc.

    -- Label anchor patterns (JSONB array of {field, signals[], value})
    -- Used by TemplateMatcher to verify field presence in new PO text
    field_anchors    JSONB       NOT NULL DEFAULT '[]'::jsonb,

    -- Reinforcement learning metrics
    use_count        INT         NOT NULL DEFAULT 1,
    avg_confidence   FLOAT       NOT NULL DEFAULT 80.0,
    last_extraction_confidence FLOAT,       -- confidence of most recent extraction
    llm_fallback_count INT       NOT NULL DEFAULT 0,  -- how many times LLM was still needed
    template_hit_count INT       NOT NULL DEFAULT 0,  -- how many times template was sufficient

    -- Timestamps
    last_used_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- One template per buyer per org
    CONSTRAINT uq_po_templates_org_buyer UNIQUE (org_id, buyer_key)
);

-- Fast lookup by org + buyer_key (primary access pattern)
CREATE INDEX IF NOT EXISTS idx_po_templates_org_buyer
    ON po_templates (org_id, buyer_key);

-- Dashboard query: list templates by org ordered by most active
CREATE INDEX IF NOT EXISTS idx_po_templates_org_use
    ON po_templates (org_id, use_count DESC);

-- Auto-update updated_at on every row change
CREATE OR REPLACE FUNCTION update_po_templates_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_po_templates_updated_at ON po_templates;
CREATE TRIGGER trg_po_templates_updated_at
    BEFORE UPDATE ON po_templates
    FOR EACH ROW EXECUTE FUNCTION update_po_templates_updated_at();

COMMENT ON TABLE  po_templates                        IS 'Buyer-specific PO extraction templates — learned and improved per shipment';
COMMENT ON COLUMN po_templates.buyer_key              IS 'Normalised slug of buyer_name — used as lookup key';
COMMENT ON COLUMN po_templates.field_anchors          IS 'JSONB array: [{field, signals, value}] — label patterns that reliably appear in this buyer PO format';
COMMENT ON COLUMN po_templates.use_count              IS 'Total times this template was consulted (matched or not)';
COMMENT ON COLUMN po_templates.template_hit_count     IS 'Times template was sufficient — LLM skipped';
COMMENT ON COLUMN po_templates.llm_fallback_count     IS 'Times LLM was still needed despite template existing';
COMMENT ON COLUMN po_templates.avg_confidence         IS 'Running average confidence across all extractions for this buyer';

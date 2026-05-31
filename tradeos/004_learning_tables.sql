-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: 004_learning_tables.sql
-- Adds two things:
--   1. hitl_corrections  — stores every field-level human correction
--   2. org_rules column on organizations — per-org commodity/HS overrides
--
-- Run after 003_po_templates.sql
-- Zero changes to existing tables except one ALTER TABLE on organizations.
-- ─────────────────────────────────────────────────────────────────────────────


-- ── 1. HITL CORRECTIONS ──────────────────────────────────────────────────────
-- Every time a human changes a field during HITL review, we store it here.
-- This is the feedback signal that drives template improvement.

CREATE TABLE IF NOT EXISTS hitl_corrections (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID        NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    workflow_id     UUID        NOT NULL,
    order_id        UUID,                               -- nullable: order may not exist yet
    buyer_key       TEXT,                               -- normalised slug, matches po_templates.buyer_key
    field_name      TEXT        NOT NULL,               -- e.g. "incoterms", "destination_port"
    wrong_value     TEXT,                               -- what the system extracted (may be null if field was missing)
    correct_value   TEXT        NOT NULL,               -- what the human set
    correction_source TEXT      NOT NULL DEFAULT 'hitl_approval',  -- hitl_approval | manual_edit
    corrected_by    UUID        REFERENCES users(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hitl_corrections_org_buyer
    ON hitl_corrections (org_id, buyer_key);

CREATE INDEX IF NOT EXISTS idx_hitl_corrections_org_field
    ON hitl_corrections (org_id, field_name);

CREATE INDEX IF NOT EXISTS idx_hitl_corrections_workflow
    ON hitl_corrections (workflow_id);

COMMENT ON TABLE  hitl_corrections IS 'Field-level human corrections from HITL review — used to improve per-org templates';
COMMENT ON COLUMN hitl_corrections.buyer_key IS 'Matches po_templates.buyer_key — links corrections back to the template they should improve';
COMMENT ON COLUMN hitl_corrections.wrong_value IS 'Value the system extracted before human correction; NULL if field was entirely missing';


-- ── 2. ORG-LEVEL EXTRACTION RULES ────────────────────────────────────────────
-- A JSONB column on organizations for per-org commodity overrides.
-- Stored as: { "commodity_hs": {"basmati rice": "100630", ...},
--              "unit_aliases": {"bags": "BAG", ...},
--              "default_incoterms": "CIF",
--              "default_currency": "USD" }
--
-- Adding a column to organizations — no existing row is affected
-- because DEFAULT '{}' fills it for all existing orgs automatically.

ALTER TABLE organizations
    ADD COLUMN IF NOT EXISTS extraction_rules JSONB NOT NULL DEFAULT '{}';

COMMENT ON COLUMN organizations.extraction_rules IS
    'Per-org extraction overrides: commodity_hs map, unit_aliases, default_incoterms, default_currency. '
    'Merged with global COMMODITY_HS in RuleBasedExtractor at runtime.';

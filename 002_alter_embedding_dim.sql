-- ============================================================
-- TradeOS — Migration 002
-- Change embedding vector dimension: 1536 → 384
-- Reason: using sentence-transformers/all-MiniLM-L6-v2 locally
--         (already in requirements.txt) which outputs 384 dims.
--         Avoids OpenAI dependency for embeddings entirely.
-- Run once:
--   docker exec -i postgres psql -U tradeos -d tradeos < 002_alter_embedding_dim.sql
-- ============================================================

-- Drop the ivfflat index first (cannot alter a column that has a vector index)
DROP INDEX IF EXISTS idx_memory_embedding;
DROP INDEX IF EXISTS idx_hs_embedding;

-- Alter agent_memory embedding column
ALTER TABLE agent_memory
    ALTER COLUMN embedding TYPE vector(384)
    USING NULL;   -- existing 1536-dim rows become NULL; re-embedded on next access

-- Alter hs_codes embedding column (also vector(1536) per schema)
ALTER TABLE hs_codes
    ALTER COLUMN embedding TYPE vector(384)
    USING NULL;

-- Recreate indexes with correct dimension
CREATE INDEX IF NOT EXISTS idx_memory_embedding
    ON agent_memory USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);

CREATE INDEX IF NOT EXISTS idx_hs_embedding
    ON hs_codes USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);

-- Confirm
DO $$
BEGIN
    RAISE NOTICE 'Migration 002 complete — embedding columns are now vector(384)';
END $$;

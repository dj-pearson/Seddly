-- Add soft delete support for commitments and entities
-- Privacy Policy requires 30-day retention after deletion

ALTER TABLE commitments ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE entities ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Index for efficient soft delete queries
CREATE INDEX IF NOT EXISTS idx_commitments_deleted_at ON commitments(deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_entities_deleted_at ON entities(deleted_at) WHERE deleted_at IS NOT NULL;

-- Update RLS policies to exclude soft-deleted rows from normal queries
-- Existing policies filter by user_id; add deleted_at IS NULL condition

-- Drop and recreate commitments select policy with soft delete filter
DROP POLICY IF EXISTS "Users can view own commitments" ON commitments;
CREATE POLICY "Users can view own commitments" ON commitments
  FOR SELECT USING (auth.uid() = user_id AND deleted_at IS NULL);

DROP POLICY IF EXISTS "Users can view own entities" ON entities;
CREATE POLICY "Users can view own entities" ON entities
  FOR SELECT USING (auth.uid() = user_id AND deleted_at IS NULL);

-- Hard delete job: remove rows older than 30 days after soft delete
-- This enforces the Privacy Policy retention period
-- Run via pg_cron: SELECT cron.schedule('hard-delete-expired', '0 3 * * *', $$
--   DELETE FROM commitments WHERE deleted_at IS NOT NULL AND deleted_at < NOW() - INTERVAL '30 days';
--   DELETE FROM entities WHERE deleted_at IS NOT NULL AND deleted_at < NOW() - INTERVAL '30 days';
-- $$);

-- Create a function for the hard delete job (can be called by pg_cron or manually)
CREATE OR REPLACE FUNCTION hard_delete_expired_records()
RETURNS void AS $$
BEGIN
  DELETE FROM commitments WHERE deleted_at IS NOT NULL AND deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM entities WHERE deleted_at IS NOT NULL AND deleted_at < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

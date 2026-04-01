-- Loop 5 Security Hardening Migration
-- US-099: Fix soft delete RLS policies
-- US-100: Add database constraints for data integrity
-- US-101: Enable pg_cron hard delete job for GDPR compliance
-- US-102: Fix processing_log INSERT policy
-- US-105: Add server-side auth event logging table

-- ============================================================================
-- US-099: Fix soft delete RLS policies
-- Block UPDATE/DELETE on soft-deleted rows to enforce 30-day retention
-- ============================================================================

-- Commitments: drop the broad "FOR ALL" policy and replace with granular ones
DROP POLICY IF EXISTS "commitments_own_data" ON commitments;

-- SELECT: users can read their own data (including soft-deleted for recovery UI)
CREATE POLICY "commitments_select_own" ON commitments
    FOR SELECT USING (auth.uid() = user_id);

-- INSERT: users can insert their own data
CREATE POLICY "commitments_insert_own" ON commitments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- UPDATE: users can only update non-deleted rows they own
CREATE POLICY "commitments_update_own" ON commitments
    FOR UPDATE USING (auth.uid() = user_id AND deleted_at IS NULL);

-- DELETE: users can only delete non-deleted rows they own
CREATE POLICY "commitments_delete_own" ON commitments
    FOR DELETE USING (auth.uid() = user_id AND deleted_at IS NULL);

-- Entities: same treatment
DROP POLICY IF EXISTS "entities_own_data" ON entities;

CREATE POLICY "entities_select_own" ON entities
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "entities_insert_own" ON entities
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "entities_update_own" ON entities
    FOR UPDATE USING (auth.uid() = user_id AND deleted_at IS NULL);

CREATE POLICY "entities_delete_own" ON entities
    FOR DELETE USING (auth.uid() = user_id AND deleted_at IS NULL);

-- ============================================================================
-- US-100: Add database constraints for data integrity
-- ============================================================================

-- Clean up any existing invalid data before adding constraints
UPDATE commitments SET confidence = 0 WHERE confidence < 0;
UPDATE commitments SET confidence = 10 WHERE confidence > 10;
UPDATE commitments SET dollar_amount = 0 WHERE dollar_amount < 0;

-- Add CHECK constraint for confidence range (0-10)
ALTER TABLE commitments ADD CONSTRAINT chk_confidence_range
    CHECK (confidence >= 0 AND confidence <= 10);

-- Add CHECK constraint for dollar_amount non-negative
ALTER TABLE commitments ADD CONSTRAINT chk_dollar_amount_non_negative
    CHECK (dollar_amount IS NULL OR dollar_amount >= 0);

-- entity_name and summary already have NOT NULL from initial schema, verify they're non-empty
ALTER TABLE commitments ADD CONSTRAINT chk_entity_name_not_empty
    CHECK (length(trim(entity_name)) > 0);

ALTER TABLE commitments ADD CONSTRAINT chk_summary_not_empty
    CHECK (length(trim(summary)) > 0);

-- ============================================================================
-- US-101: Enable pg_cron hard delete job for GDPR compliance
-- ============================================================================

-- Replace the hard delete function with one that also logs execution
CREATE OR REPLACE FUNCTION hard_delete_expired_records()
RETURNS void AS $$
DECLARE
    deleted_commitments INT;
    deleted_entities INT;
BEGIN
    -- Delete expired commitments
    DELETE FROM commitments
    WHERE deleted_at IS NOT NULL AND deleted_at < NOW() - INTERVAL '30 days';
    GET DIAGNOSTICS deleted_commitments = ROW_COUNT;

    -- Delete expired entities
    DELETE FROM entities
    WHERE deleted_at IS NOT NULL AND deleted_at < NOW() - INTERVAL '30 days';
    GET DIAGNOSTICS deleted_entities = ROW_COUNT;

    -- Log execution to processing_log
    INSERT INTO processing_log (device_id, screenshots_processed, commitments_extracted, false_positive_dismissals, manual_additions)
    VALUES ('system:hard_delete_cron', deleted_commitments, deleted_entities, 0, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule pg_cron job to run daily at 3:00 AM UTC
-- Note: Requires pg_cron extension enabled on Supabase instance
-- Uncomment to activate:
-- SELECT cron.schedule('hard-delete-expired', '0 3 * * *', $$SELECT hard_delete_expired_records()$$);

-- ============================================================================
-- US-102: Fix processing_log INSERT policy
-- ============================================================================

-- Drop the overly permissive INSERT policy
DROP POLICY IF EXISTS "processing_log_service_insert" ON processing_log;

-- Only allow service role (Edge Functions) to insert
-- Regular authenticated users cannot insert into processing_log
-- Note: Service role bypasses RLS entirely, so this policy blocks
-- authenticated users while service role access is unaffected.
CREATE POLICY "processing_log_deny_user_insert" ON processing_log
    FOR INSERT WITH CHECK (false);

-- ============================================================================
-- US-105: Add server-side auth event logging table
-- ============================================================================

CREATE TABLE auth_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK (event_type IN (
        'auth_success', 'auth_failed', 'auth_missing',
        'subscription_check_failed', 'rate_limited',
        'token_refresh', 'sign_out', 'account_deleted'
    )),
    ip_address TEXT,
    user_agent TEXT,
    details TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE auth_events ENABLE ROW LEVEL SECURITY;

-- Users can read their own auth events
CREATE POLICY "auth_events_select_own" ON auth_events
    FOR SELECT USING (auth.uid() = user_id);

-- Only service role can insert (Edge Functions)
-- Regular users cannot insert auth events directly
CREATE POLICY "auth_events_deny_user_insert" ON auth_events
    FOR INSERT WITH CHECK (false);

-- Index for efficient querying
CREATE INDEX idx_auth_events_user_created ON auth_events(user_id, created_at DESC);
CREATE INDEX idx_auth_events_type ON auth_events(event_type, created_at DESC);

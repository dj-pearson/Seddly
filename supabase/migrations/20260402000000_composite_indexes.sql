-- Composite indexes for common query patterns (US-114)
-- These optimize the most frequent queries in the Seddly app

-- 1. Sync pull query: user's commitments ordered by creation date (used by SyncService.pullCommitments)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_commitments_user_created
    ON commitments(user_id, created_at ASC);

-- 2. Active commitments with deadlines: used by overdue detection, widget, and ledger filtering
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_commitments_user_status_deadline
    ON commitments(user_id, status, deadline)
    WHERE deleted_at IS NULL;

-- 3. Entity commitments: used by EntityProfileView to show related commitments
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_commitments_user_entity_created
    ON commitments(user_id, entity_name, created_at DESC)
    WHERE deleted_at IS NULL;

-- 4. Auth events lookup: used for security monitoring and rate limit decisions
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_auth_events_user_type_created
    ON auth_events(user_id, event_type, created_at DESC);

-- 5. Subscription expiry check: used by cron jobs to find expiring subscriptions
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_subscription_expires
    ON users(subscription_status, subscription_expires_at)
    WHERE subscription_tier != 'free';

-- 6. Soft-deleted records cleanup: used by hard_delete_expired_records()
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_commitments_deleted_at
    ON commitments(deleted_at)
    WHERE deleted_at IS NOT NULL;

-- 7. Processing log date range: used for analytics dashboards
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_processing_log_processed_at
    ON processing_log(processed_at DESC);

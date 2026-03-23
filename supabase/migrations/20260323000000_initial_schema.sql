-- Seddly Initial Database Schema
-- Only used by Pro+ tier for cloud sync and by Edge Functions

-- Users table (Pro+ accounts only — free/Pro users have no server-side account)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apple_user_id TEXT UNIQUE NOT NULL,
    apple_transaction_id TEXT,
    email TEXT,
    device_token TEXT,
    subscription_tier TEXT NOT NULL DEFAULT 'free' CHECK (subscription_tier IN ('free', 'pro', 'pro_plus')),
    subscription_status TEXT NOT NULL DEFAULT 'active' CHECK (subscription_status IN ('active', 'billing_retry', 'expired', 'refunded')),
    subscription_expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Commitments table (Pro+ sync only)
CREATE TABLE commitments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    entity_name TEXT NOT NULL,
    summary TEXT NOT NULL,
    full_text TEXT NOT NULL,
    deadline TIMESTAMPTZ,
    dollar_amount DECIMAL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'fulfilled', 'overdue', 'disputed', 'dismissed')),
    confidence INT NOT NULL DEFAULT 0,
    ai_reasoning TEXT,
    source TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('auto', 'manual', 'share_sheet')),
    screenshot_date TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Entities table (Pro+ sync only)
CREATE TABLE entities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, name)
);

-- Processing log (analytics — all tiers via anonymous device ID)
CREATE TABLE processing_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL,
    screenshots_processed INT NOT NULL DEFAULT 0,
    commitments_extracted INT NOT NULL DEFAULT 0,
    false_positive_dismissals INT NOT NULL DEFAULT 0,
    manual_additions INT NOT NULL DEFAULT 0,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_commitments_user_id ON commitments(user_id);
CREATE INDEX idx_commitments_status ON commitments(user_id, status);
CREATE INDEX idx_commitments_deadline ON commitments(user_id, deadline) WHERE deadline IS NOT NULL;
CREATE INDEX idx_entities_user_id ON entities(user_id);
CREATE INDEX idx_users_apple_user_id ON users(apple_user_id);
CREATE INDEX idx_users_apple_transaction_id ON users(apple_transaction_id);
CREATE INDEX idx_users_subscription ON users(subscription_tier, subscription_status);

-- Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE commitments ENABLE ROW LEVEL SECURITY;
ALTER TABLE entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE processing_log ENABLE ROW LEVEL SECURITY;

-- Users can only read/write their own data
CREATE POLICY "users_own_data" ON users
    FOR ALL USING (auth.uid() = id);

CREATE POLICY "commitments_own_data" ON commitments
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "entities_own_data" ON entities
    FOR ALL USING (auth.uid() = user_id);

-- Processing log is write-only from Edge Functions (service role), no user reads
CREATE POLICY "processing_log_service_insert" ON processing_log
    FOR INSERT WITH CHECK (true);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER commitments_updated_at BEFORE UPDATE ON commitments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER entities_updated_at BEFORE UPDATE ON entities
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- pg_cron job for silent push (runs twice daily at 8am and 8pm UTC)
-- Note: This requires pg_cron extension enabled on your Supabase instance
-- SELECT cron.schedule('send-morning-push', '0 8 * * *', $$SELECT net.http_post(url := 'YOUR_SUPABASE_URL/functions/v1/send-silent-push', body := '{}'::jsonb)$$);
-- SELECT cron.schedule('send-evening-push', '0 20 * * *', $$SELECT net.http_post(url := 'YOUR_SUPABASE_URL/functions/v1/send-silent-push', body := '{}'::jsonb)$$);

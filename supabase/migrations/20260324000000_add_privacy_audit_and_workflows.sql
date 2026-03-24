-- Privacy audit log table (Pro+ sync)
CREATE TABLE privacy_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
    event_type TEXT NOT NULL CHECK (event_type IN ('ai_extraction', 'dispute_summary', 'cloud_sync')),
    destination TEXT NOT NULL,
    data_summary TEXT NOT NULL,
    text_length_sent INT NOT NULL DEFAULT 0,
    commitment_id UUID REFERENCES commitments(id) ON DELETE SET NULL
);

CREATE INDEX idx_privacy_audit_user_id ON privacy_audit_log(user_id);
CREATE INDEX idx_privacy_audit_event_type ON privacy_audit_log(user_id, event_type);

-- Custom workflows table (Pro+ sync)
CREATE TABLE custom_workflows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    steps JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_default BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_workflows_user_id ON custom_workflows(user_id);

-- Row Level Security
ALTER TABLE privacy_audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE custom_workflows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "privacy_audit_own_data" ON privacy_audit_log
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "workflows_own_data" ON custom_workflows
    FOR ALL USING (auth.uid() = user_id);

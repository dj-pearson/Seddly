-- Performance indexes for frequently queried columns

-- Index on commitments(user_id, confidence) for filtered queries
CREATE INDEX IF NOT EXISTS idx_commitments_confidence ON commitments(user_id, confidence);

-- Index on privacy_audit_log(user_id, timestamp DESC) for time-range queries
CREATE INDEX IF NOT EXISTS idx_privacy_audit_timestamp ON privacy_audit_log(user_id, timestamp DESC);

-- Index on processing_log(device_id, processed_at DESC) for device analytics
CREATE INDEX IF NOT EXISTS idx_processing_log_device ON processing_log(device_id, processed_at DESC);

-- Index on custom_workflows(user_id, created_at DESC) for listing
CREATE INDEX IF NOT EXISTS idx_workflows_created ON custom_workflows(user_id, created_at DESC);

-- Change dollar_amount to DECIMAL(10,2) for precision
ALTER TABLE commitments ALTER COLUMN dollar_amount TYPE DECIMAL(10,2);

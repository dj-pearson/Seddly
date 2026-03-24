-- Add Phase 4 fields to commitments table for full sync support
ALTER TABLE commitments
ADD COLUMN calendar_event_id TEXT,
ADD COLUMN custom_status_label TEXT,
ADD COLUMN workflow_id UUID REFERENCES custom_workflows(id) ON DELETE SET NULL;

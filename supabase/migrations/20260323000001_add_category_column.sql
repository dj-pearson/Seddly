-- Add category column to commitments table (Phase 3 feature)
ALTER TABLE commitments
ADD COLUMN category TEXT NOT NULL DEFAULT 'uncategorized'
CHECK (category IN ('housing', 'freelance', 'purchases', 'personal', 'medical', 'insurance', 'uncategorized'));

-- Add index for category filtering
CREATE INDEX idx_commitments_category ON commitments(user_id, category);

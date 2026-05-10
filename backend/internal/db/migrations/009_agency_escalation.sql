ALTER TABLE reports
    ADD COLUMN IF NOT EXISTS agency_escalation_status VARCHAR(16)
        CHECK (agency_escalation_status IN ('pending', 'sent', 'failed')),
    ADD COLUMN IF NOT EXISTS agency_escalation_reason TEXT,
    ADD COLUMN IF NOT EXISTS agency_escalation_requested_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS agency_escalation_sent_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS agency_escalation_failed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS agency_escalation_last_error TEXT;

CREATE INDEX IF NOT EXISTS idx_reports_agency_escalation_status
    ON reports(agency_escalation_status)
    WHERE agency_escalation_status IS NOT NULL;
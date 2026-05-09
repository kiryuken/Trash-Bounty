CREATE TYPE report_status AS ENUM ('pending', 'ai_analyzing', 'approved', 'rejected', 'bounty_created', 'completed');
CREATE TYPE waste_type AS ENUM ('organic', 'plastic', 'metal', 'glass', 'electronic', 'hazardous', 'mixed', 'unknown');

CREATE TABLE IF NOT EXISTS reports (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id     UUID NOT NULL REFERENCES users(id),
    image_url       VARCHAR(512) NOT NULL,
    location_text   VARCHAR(500) NOT NULL,
    latitude        DECIMAL(10,8),
    longitude       DECIMAL(11,8),

    waste_type      waste_type NOT NULL DEFAULT 'unknown',
    severity        INTEGER CHECK (severity BETWEEN 1 AND 10),
    estimated_weight_kg DECIMAL(6,2),
    ai_confidence   DECIMAL(5,4),
    ai_reasoning    TEXT,
    mini_raw_result JSONB,
    standard_raw_result JSONB,

    status          report_status NOT NULL DEFAULT 'pending',
    points_earned   INTEGER,
    reward_idr      DECIMAL(15,2),

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reports_reporter ON reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_location ON reports(latitude, longitude) WHERE latitude IS NOT NULL;

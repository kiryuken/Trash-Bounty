CREATE TYPE bounty_status AS ENUM ('open', 'taken', 'in_progress', 'completed', 'cancelled', 'disputed');

CREATE TABLE IF NOT EXISTS bounties (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    report_id       UUID NOT NULL REFERENCES reports(id),
    reporter_id     UUID NOT NULL REFERENCES users(id),
    executor_id     UUID REFERENCES users(id),

    location_text   VARCHAR(500) NOT NULL,
    address         VARCHAR(500),
    latitude        DECIMAL(10,8),
    longitude       DECIMAL(11,8),
    image_url       VARCHAR(512) NOT NULL,
    severity        INTEGER NOT NULL CHECK (severity BETWEEN 1 AND 10),
    waste_type      waste_type NOT NULL DEFAULT 'unknown',
    estimated_time_minutes INTEGER,

    reward_points   INTEGER NOT NULL,
    reward_idr      DECIMAL(15,2) NOT NULL,

    status          bounty_status NOT NULL DEFAULT 'open',
    taken_at        TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    proof_image_url VARCHAR(512),

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bounties_status ON bounties(status);
CREATE INDEX IF NOT EXISTS idx_bounties_location ON bounties(latitude, longitude) WHERE latitude IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_bounties_executor ON bounties(executor_id) WHERE executor_id IS NOT NULL;

CREATE TYPE transaction_type AS ENUM (
    'points_earned_report',
    'points_earned_bounty',
    'points_redeemed',
    'points_bonus',
    'wallet_credit',
    'wallet_debit'
);

CREATE TYPE transaction_status AS ENUM ('pending', 'completed', 'failed', 'cancelled');

CREATE TABLE IF NOT EXISTS transactions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id),
    type            transaction_type NOT NULL,
    status          transaction_status NOT NULL DEFAULT 'pending',
    points_delta    INTEGER,
    idr_delta       DECIMAL(15,2),
    reference_id    UUID,
    description     TEXT,
    qr_code_url     VARCHAR(512),
    qr_expires_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_transactions_user ON transactions(user_id, created_at DESC);

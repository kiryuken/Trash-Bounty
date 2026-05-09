CREATE TYPE achievement_type AS ENUM (
    'first_report', 'reports_10', 'reports_25', 'reports_50', 'reports_100',
    'first_bounty', 'bounties_10', 'bounties_25', 'bounties_50',
    'top_10_weekly', 'top_10_monthly', 'top_3_alltime',
    'points_1000', 'points_5000', 'points_10000'
);

CREATE TABLE IF NOT EXISTS achievements (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type         achievement_type NOT NULL,
    earned_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, type)
);

-- Leaderboard materialized views
CREATE MATERIALIZED VIEW IF NOT EXISTS leaderboard_weekly AS
SELECT
    u.id,
    u.name,
    u.avatar_url,
    u.role::text AS role,
    COALESCE(rpts.pts, 0) + COALESCE(bnts.pts, 0) AS points,
    COALESCE(rpts.cnt, 0) + COALESCE(bnts.cnt, 0) AS tasks
FROM users u
LEFT JOIN (
    SELECT reporter_id, COALESCE(SUM(points_earned), 0) AS pts, COUNT(*) AS cnt
    FROM reports
    WHERE status IN ('approved', 'bounty_created', 'completed')
      AND updated_at >= NOW() - INTERVAL '7 days'
    GROUP BY reporter_id
) rpts ON rpts.reporter_id = u.id
LEFT JOIN (
    SELECT executor_id, COALESCE(SUM(reward_points), 0) AS pts, COUNT(*) AS cnt
    FROM bounties
    WHERE status = 'completed'
      AND completed_at >= NOW() - INTERVAL '7 days'
    GROUP BY executor_id
) bnts ON bnts.executor_id = u.id
ORDER BY points DESC;

CREATE UNIQUE INDEX IF NOT EXISTS idx_leaderboard_weekly_id ON leaderboard_weekly(id);

CREATE MATERIALIZED VIEW IF NOT EXISTS leaderboard_monthly AS
SELECT
    u.id,
    u.name,
    u.avatar_url,
    u.role::text AS role,
    COALESCE(rpts.pts, 0) + COALESCE(bnts.pts, 0) AS points,
    COALESCE(rpts.cnt, 0) + COALESCE(bnts.cnt, 0) AS tasks
FROM users u
LEFT JOIN (
    SELECT reporter_id, COALESCE(SUM(points_earned), 0) AS pts, COUNT(*) AS cnt
    FROM reports
    WHERE status IN ('approved', 'bounty_created', 'completed')
      AND updated_at >= NOW() - INTERVAL '30 days'
    GROUP BY reporter_id
) rpts ON rpts.reporter_id = u.id
LEFT JOIN (
    SELECT executor_id, COALESCE(SUM(reward_points), 0) AS pts, COUNT(*) AS cnt
    FROM bounties
    WHERE status = 'completed'
      AND completed_at >= NOW() - INTERVAL '30 days'
    GROUP BY executor_id
) bnts ON bnts.executor_id = u.id
ORDER BY points DESC;

CREATE UNIQUE INDEX IF NOT EXISTS idx_leaderboard_monthly_id ON leaderboard_monthly(id);

CREATE MATERIALIZED VIEW IF NOT EXISTS leaderboard_alltime AS
SELECT
    u.id,
    u.name,
    u.avatar_url,
    u.role::text AS role,
    u.points,
    (SELECT COUNT(*) FROM reports r WHERE r.reporter_id = u.id AND r.status IN ('approved','bounty_created','completed'))
    + (SELECT COUNT(*) FROM bounties b WHERE b.executor_id = u.id AND b.status = 'completed') AS tasks
FROM users u
ORDER BY u.points DESC;

CREATE UNIQUE INDEX IF NOT EXISTS idx_leaderboard_alltime_id ON leaderboard_alltime(id);

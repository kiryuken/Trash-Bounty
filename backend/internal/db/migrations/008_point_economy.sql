DROP MATERIALIZED VIEW IF EXISTS leaderboard_weekly;
DROP MATERIALIZED VIEW IF EXISTS leaderboard_monthly;

CREATE MATERIALIZED VIEW leaderboard_weekly AS
SELECT
    u.id,
    u.name,
    u.avatar_url,
    u.role::text AS role,
    COALESCE(tp.points, 0) AS points,
    COALESCE(rpts.cnt, 0) + COALESCE(bnts.cnt, 0) AS tasks
FROM users u
LEFT JOIN (
    SELECT user_id, COALESCE(SUM(points_delta), 0) AS points
    FROM transactions
    WHERE status = 'completed'
      AND type IN ('points_earned_report', 'points_earned_bounty', 'points_bonus')
      AND created_at >= NOW() - INTERVAL '7 days'
    GROUP BY user_id
) tp ON tp.user_id = u.id
LEFT JOIN (
    SELECT reporter_id, COUNT(*) AS cnt
    FROM reports
    WHERE status IN ('approved', 'bounty_created', 'completed')
      AND updated_at >= NOW() - INTERVAL '7 days'
    GROUP BY reporter_id
) rpts ON rpts.reporter_id = u.id
LEFT JOIN (
    SELECT executor_id, COUNT(*) AS cnt
    FROM bounties
    WHERE status = 'completed'
      AND completed_at >= NOW() - INTERVAL '7 days'
    GROUP BY executor_id
) bnts ON bnts.executor_id = u.id
ORDER BY points DESC;

CREATE UNIQUE INDEX IF NOT EXISTS idx_leaderboard_weekly_id ON leaderboard_weekly(id);

CREATE MATERIALIZED VIEW leaderboard_monthly AS
SELECT
    u.id,
    u.name,
    u.avatar_url,
    u.role::text AS role,
    COALESCE(tp.points, 0) AS points,
    COALESCE(rpts.cnt, 0) + COALESCE(bnts.cnt, 0) AS tasks
FROM users u
LEFT JOIN (
    SELECT user_id, COALESCE(SUM(points_delta), 0) AS points
    FROM transactions
    WHERE status = 'completed'
      AND type IN ('points_earned_report', 'points_earned_bounty', 'points_bonus')
      AND created_at >= NOW() - INTERVAL '30 days'
    GROUP BY user_id
) tp ON tp.user_id = u.id
LEFT JOIN (
    SELECT reporter_id, COUNT(*) AS cnt
    FROM reports
    WHERE status IN ('approved', 'bounty_created', 'completed')
      AND updated_at >= NOW() - INTERVAL '30 days'
    GROUP BY reporter_id
) rpts ON rpts.reporter_id = u.id
LEFT JOIN (
    SELECT executor_id, COUNT(*) AS cnt
    FROM bounties
    WHERE status = 'completed'
      AND completed_at >= NOW() - INTERVAL '30 days'
    GROUP BY executor_id
) bnts ON bnts.executor_id = u.id
ORDER BY points DESC;

CREATE UNIQUE INDEX IF NOT EXISTS idx_leaderboard_monthly_id ON leaderboard_monthly(id);
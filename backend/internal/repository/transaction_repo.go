package repository

import (
	"context"
	"database/sql"
	"fmt"

	"trashbounty/internal/model"
)

type TransactionRepo struct {
	DB *sql.DB
}

func NewTransactionRepo(db *sql.DB) *TransactionRepo {
	return &TransactionRepo{DB: db}
}

func (r *TransactionRepo) Create(ctx context.Context, t *model.Transaction) error {
	return r.DB.QueryRowContext(ctx, `
		INSERT INTO transactions (user_id, type, status, points_delta, idr_delta, reference_id, description)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, created_at`,
		t.UserID, t.Type, t.Status, t.PointsDelta, t.IDRDelta, t.ReferenceID, t.Description,
	).Scan(&t.ID, &t.CreatedAt)
}

func (r *TransactionRepo) ListByUser(ctx context.Context, userID string, limit, offset int) ([]model.Transaction, error) {
	rows, err := r.DB.QueryContext(ctx, `
		SELECT id, user_id, type, status, points_delta, idr_delta, reference_id, description,
		       qr_code_url, qr_expires_at, created_at, completed_at
		FROM transactions WHERE user_id = $1
		ORDER BY created_at DESC LIMIT $2 OFFSET $3`, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []model.Transaction
	for rows.Next() {
		var t model.Transaction
		if err := rows.Scan(&t.ID, &t.UserID, &t.Type, &t.Status, &t.PointsDelta, &t.IDRDelta,
			&t.ReferenceID, &t.Description, &t.QRCodeURL, &t.QRExpiresAt,
			&t.CreatedAt, &t.CompletedAt); err != nil {
			return nil, err
		}
		results = append(results, t)
	}
	return results, rows.Err()
}

func (r *TransactionRepo) Complete(ctx context.Context, id string) error {
	_, err := r.DB.ExecContext(ctx, `UPDATE transactions SET status='completed', completed_at=NOW() WHERE id=$1`, id)
	return err
}

type LeaderboardRepo struct {
	DB *sql.DB
}

func NewLeaderboardRepo(db *sql.DB) *LeaderboardRepo {
	return &LeaderboardRepo{DB: db}
}

func (r *LeaderboardRepo) GetLeaderboard(ctx context.Context, period string, limit int, role string) ([]model.LeaderboardEntry, error) {
	view := "leaderboard_alltime"
	switch period {
	case "weekly":
		view = "leaderboard_weekly"
	case "monthly":
		view = "leaderboard_monthly"
	}

	query := `SELECT id, name, avatar_url, role, points, tasks FROM ` + view + ` WHERE points > 0`
	args := []any{}
	argIdx := 1

	if role != "" && role != "all" {
		query += fmt.Sprintf(` AND role = $%d`, argIdx)
		args = append(args, role)
		argIdx++
	}

	query += ` ORDER BY points DESC LIMIT $` + fmt.Sprintf("%d", argIdx)
	args = append(args, limit)

	rows, err := r.DB.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []model.LeaderboardEntry
	rank := 0
	for rows.Next() {
		rank++
		var e model.LeaderboardEntry
		var avatarURL sql.NullString
		if err := rows.Scan(&e.ID, &e.Name, &avatarURL, &e.Role, &e.Points, &e.Tasks); err != nil {
			return nil, err
		}
		if avatarURL.Valid {
			e.AvatarURL = &avatarURL.String
		}
		e.Rank = rank
		// Assign badge based on rank
		switch rank {
		case 1:
			e.Badge = "gold"
		case 2:
			e.Badge = "silver"
		case 3:
			e.Badge = "bronze"
		default:
			e.Badge = ""
		}
		results = append(results, e)
	}
	return results, rows.Err()
}

func (r *LeaderboardRepo) RefreshViews() error {
	for _, v := range []string{"leaderboard_weekly", "leaderboard_monthly", "leaderboard_alltime"} {
		if _, err := r.DB.Exec(`REFRESH MATERIALIZED VIEW CONCURRENTLY ` + v); err != nil {
			return err
		}
	}
	return nil
}

type StatsRepo struct {
	DB *sql.DB
}

func NewStatsRepo(db *sql.DB) *StatsRepo {
	return &StatsRepo{DB: db}
}

func (r *StatsRepo) GetHomeStats(ctx context.Context, userID string) (*model.HomeStats, error) {
	s := &model.HomeStats{}
	err := r.DB.QueryRowContext(ctx, `
		SELECT
			u.points AS total_points,
			u.wallet_balance,
			u.rank AS current_rank,
			(SELECT COUNT(*) FROM reports WHERE reporter_id = $1) AS total_reports,
			(SELECT COUNT(*) FROM bounties WHERE status IN ('open','taken','in_progress') AND executor_id IS NULL) AS pending_bounties
		FROM users u WHERE u.id = $1
	`, userID).Scan(&s.TotalPoints, &s.WalletBalance, &s.CurrentRank, &s.TotalReports, &s.PendingBounties)
	return s, err
}

func (r *StatsRepo) GetGlobalCleanupStats(ctx context.Context, period string) (*model.CleanupStats, error) {
	stats := &model.CleanupStats{Period: period, WasteTypes: []model.WasteTypeStat{}}
	condition, err := cleanupPeriodCondition(period)
	if err != nil {
		return nil, err
	}

	query := fmt.Sprintf(`
		SELECT
			COUNT(*) AS total_completed,
			COALESCE(SUM(b.reward_points), 0) AS total_points_awarded,
			COALESCE(SUM(b.reward_idr), 0) AS total_reward_idr,
			COALESCE(SUM(r.estimated_weight_kg), 0) AS total_weight_kg
		FROM bounties b
		LEFT JOIN reports r ON r.id = b.report_id
		WHERE b.status = 'completed' %s
	`, condition)

	err = r.DB.QueryRowContext(ctx, query).Scan(
		&stats.TotalCompleted,
		&stats.TotalPointsAwarded,
		&stats.TotalRewardIDR,
		&stats.TotalWeightKG,
	)
	if err != nil {
		return nil, err
	}

	return stats, nil
}

func (r *StatsRepo) GetWasteTypeBreakdown(ctx context.Context, period string) ([]model.WasteTypeStat, error) {
	condition, err := cleanupPeriodCondition(period)
	if err != nil {
		return nil, err
	}

	query := fmt.Sprintf(`
		SELECT
			b.waste_type,
			COUNT(*) AS total_count,
			COALESCE(AVG(b.severity), 0) AS avg_severity
		FROM bounties b
		LEFT JOIN reports r ON r.id = b.report_id
		WHERE b.status = 'completed' AND NULLIF(b.waste_type::text, '') IS NOT NULL %s
		GROUP BY b.waste_type
		ORDER BY total_count DESC, b.waste_type ASC
	`, condition)

	rows, err := r.DB.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	results := make([]model.WasteTypeStat, 0)
	for rows.Next() {
		var item model.WasteTypeStat
		if err := rows.Scan(&item.WasteType, &item.Count, &item.AvgSeverity); err != nil {
			return nil, err
		}
		results = append(results, item)
	}

	return results, rows.Err()
}

func cleanupPeriodCondition(period string) (string, error) {
	switch period {
	case "weekly":
		return "AND b.completed_at >= NOW() - INTERVAL '7 days'", nil
	case "monthly":
		return "AND b.completed_at >= NOW() - INTERVAL '30 days'", nil
	case "alltime":
		return "", nil
	default:
		return "", fmt.Errorf("period harus weekly, monthly, atau alltime")
	}
}

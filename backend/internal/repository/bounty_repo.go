package repository

import (
	"context"
	"database/sql"

	"trashbounty/internal/model"
)

type BountyRepo struct {
	DB *sql.DB
}

func NewBountyRepo(db *sql.DB) *BountyRepo {
	return &BountyRepo{DB: db}
}

func (r *BountyRepo) Create(ctx context.Context, b *model.Bounty) error {
	return r.DB.QueryRowContext(ctx, `
		INSERT INTO bounties (report_id, reporter_id, location_text, waste_type, severity,
		                      estimated_time_minutes, reward_points, reward_idr, latitude, longitude, image_url)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		RETURNING id, status, created_at, updated_at`,
		b.ReportID, b.ReporterID, b.LocationText, b.WasteType, b.Severity,
		b.EstimatedTimeMinutes, b.RewardPoints, b.RewardIDR, b.Latitude, b.Longitude, b.ImageURL,
	).Scan(&b.ID, &b.Status, &b.CreatedAt, &b.UpdatedAt)
}

func (r *BountyRepo) GetByID(ctx context.Context, id string) (*model.Bounty, error) {
	b := &model.Bounty{}
	err := r.DB.QueryRowContext(ctx, `
		SELECT id, report_id, reporter_id, executor_id, location_text, address, waste_type, severity,
		       estimated_time_minutes, reward_points, reward_idr, latitude, longitude, image_url, status,
		       proof_image_url, taken_at, completed_at, created_at, updated_at
		FROM bounties WHERE id = $1`, id,
	).Scan(&b.ID, &b.ReportID, &b.ReporterID, &b.ExecutorID, &b.LocationText, &b.Address,
		&b.WasteType, &b.Severity, &b.EstimatedTimeMinutes, &b.RewardPoints, &b.RewardIDR,
		&b.Latitude, &b.Longitude, &b.ImageURL, &b.Status,
		&b.ProofImageURL, &b.TakenAt, &b.CompletedAt, &b.CreatedAt, &b.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return b, nil
}

func (r *BountyRepo) ListOpen(ctx context.Context, limit, offset int) ([]model.BountySummary, error) {
	rows, err := r.DB.QueryContext(ctx, `
		SELECT id, location_text, waste_type, severity, estimated_time_minutes,
		       reward_points, reward_idr, status, image_url,
		       to_char(created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
		FROM bounties WHERE status = 'open'
		ORDER BY created_at DESC LIMIT $1 OFFSET $2`, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []model.BountySummary
	for rows.Next() {
		var s model.BountySummary
		if err := rows.Scan(&s.ID, &s.LocationText, &s.WasteType, &s.Severity,
			&s.EstimatedTimeMinutes, &s.RewardPoints, &s.RewardIDR, &s.Status, &s.ImageURL, &s.CreatedAt); err != nil {
			return nil, err
		}
		results = append(results, s)
	}
	return results, rows.Err()
}

func (r *BountyRepo) ListOpenDetailed(ctx context.Context, limit, offset int) ([]model.Bounty, error) {
	rows, err := r.DB.QueryContext(ctx, `
		SELECT id, report_id, reporter_id, location_text, waste_type, severity,
		       estimated_time_minutes, reward_points, reward_idr, latitude, longitude,
		       image_url, status, created_at, updated_at
		FROM bounties WHERE status = 'open'
		ORDER BY created_at DESC LIMIT $1 OFFSET $2`, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []model.Bounty
	for rows.Next() {
		var b model.Bounty
		if err := rows.Scan(
			&b.ID,
			&b.ReportID,
			&b.ReporterID,
			&b.LocationText,
			&b.WasteType,
			&b.Severity,
			&b.EstimatedTimeMinutes,
			&b.RewardPoints,
			&b.RewardIDR,
			&b.Latitude,
			&b.Longitude,
			&b.ImageURL,
			&b.Status,
			&b.CreatedAt,
			&b.UpdatedAt,
		); err != nil {
			return nil, err
		}
		results = append(results, b)
	}
	return results, rows.Err()
}

func (r *BountyRepo) ListByExecutor(ctx context.Context, userID string, limit, offset int) ([]model.BountySummary, error) {
	rows, err := r.DB.QueryContext(ctx, `
		SELECT id, location_text, waste_type, severity, estimated_time_minutes,
		       reward_points, reward_idr, status, image_url,
		       to_char(created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
		FROM bounties WHERE executor_id = $1
		ORDER BY created_at DESC LIMIT $2 OFFSET $3`, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []model.BountySummary
	for rows.Next() {
		var s model.BountySummary
		if err := rows.Scan(&s.ID, &s.LocationText, &s.WasteType, &s.Severity,
			&s.EstimatedTimeMinutes, &s.RewardPoints, &s.RewardIDR, &s.Status, &s.ImageURL, &s.CreatedAt); err != nil {
			return nil, err
		}
		results = append(results, s)
	}
	return results, rows.Err()
}

func (r *BountyRepo) ListByReporter(ctx context.Context, userID string, limit, offset int) ([]model.BountySummary, error) {
	rows, err := r.DB.QueryContext(ctx, `
		SELECT id, location_text, waste_type, severity, estimated_time_minutes,
		       reward_points, reward_idr, status, image_url,
		       to_char(created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
		FROM bounties WHERE reporter_id = $1
		ORDER BY created_at DESC LIMIT $2 OFFSET $3`, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []model.BountySummary
	for rows.Next() {
		var s model.BountySummary
		if err := rows.Scan(&s.ID, &s.LocationText, &s.WasteType, &s.Severity,
			&s.EstimatedTimeMinutes, &s.RewardPoints, &s.RewardIDR, &s.Status, &s.ImageURL, &s.CreatedAt); err != nil {
			return nil, err
		}
		results = append(results, s)
	}
	return results, rows.Err()
}

func (r *BountyRepo) Take(ctx context.Context, id, executorID string) (bool, error) {
	result, err := r.DB.ExecContext(ctx, `
		UPDATE bounties SET executor_id=$1, status='taken', taken_at=NOW(), updated_at=NOW()
		WHERE id=$2 AND status='open'`, executorID, id)
	if err != nil {
		return false, err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return false, err
	}
	return rows == 1, nil
}

func (r *BountyRepo) Complete(ctx context.Context, id, executorID, proofURL string) (bool, error) {
	result, err := r.DB.ExecContext(ctx, `
		UPDATE bounties SET proof_image_url=$1, status='completed', completed_at=NOW(), updated_at=NOW()
		WHERE id=$2 AND executor_id=$3 AND status IN ('taken', 'in_progress')`, proofURL, id, executorID)
	if err != nil {
		return false, err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return false, err
	}
	return rows == 1, nil
}

func (r *BountyRepo) UpdateStatus(ctx context.Context, id, status string) error {
	_, err := r.DB.ExecContext(ctx, `UPDATE bounties SET status=$1, updated_at=NOW() WHERE id=$2`, status, id)
	return err
}

func (r *BountyRepo) CountCompletedByUser(ctx context.Context, userID string) (int, error) {
	var count int
	err := r.DB.QueryRowContext(ctx, `SELECT COUNT(*) FROM bounties WHERE executor_id = $1 AND status = 'completed'`, userID).Scan(&count)
	return count, err
}

func (r *BountyRepo) GetCompletedWasteTypes(ctx context.Context, executorID string) ([]string, error) {
	rows, err := r.DB.QueryContext(ctx, `
		SELECT DISTINCT COALESCE(r.waste_type, '')
		FROM bounties b
		JOIN reports r ON r.id = b.report_id
		WHERE b.executor_id = $1 AND b.status = 'completed'`, executorID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var wasteTypes []string
	for rows.Next() {
		var wasteType string
		if err := rows.Scan(&wasteType); err != nil {
			return nil, err
		}
		if wasteType != "" {
			wasteTypes = append(wasteTypes, wasteType)
		}
	}
	return wasteTypes, rows.Err()
}

package repository

import (
	"context"
	"database/sql"
	"encoding/json"

	"trashbounty/internal/model"
)

type ReportRepo struct {
	DB *sql.DB
}

func NewReportRepo(db *sql.DB) *ReportRepo {
	return &ReportRepo{DB: db}
}

func (r *ReportRepo) Create(ctx context.Context, rpt *model.Report) error {
	return r.DB.QueryRowContext(ctx, `
		INSERT INTO reports (reporter_id, image_url, location_text, latitude, longitude)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, status, created_at, updated_at`,
		rpt.ReporterID, rpt.ImageURL, rpt.LocationText,
		rpt.Latitude, rpt.Longitude,
	).Scan(&rpt.ID, &rpt.Status, &rpt.CreatedAt, &rpt.UpdatedAt)
}

func (r *ReportRepo) GetByID(ctx context.Context, id string) (*model.Report, error) {
	rpt := &model.Report{}
	var miniRaw, stdRaw []byte
	err := r.DB.QueryRowContext(ctx, `
		SELECT id, reporter_id, image_url, location_text, latitude, longitude,
		       status, waste_type, severity, estimated_weight_kg, ai_confidence, ai_reasoning,
		       mini_raw_result, standard_raw_result, points_earned, reward_idr, created_at, updated_at
		FROM reports WHERE id = $1`, id,
	).Scan(&rpt.ID, &rpt.ReporterID, &rpt.ImageURL,
		&rpt.LocationText, &rpt.Latitude, &rpt.Longitude, &rpt.Status,
		&rpt.WasteType, &rpt.Severity, &rpt.EstimatedWeightKG, &rpt.AiConfidence, &rpt.AiReasoning,
		&miniRaw, &stdRaw, &rpt.PointsEarned, &rpt.RewardIDR, &rpt.CreatedAt, &rpt.UpdatedAt)
	if err != nil {
		return nil, err
	}
	if miniRaw != nil {
		raw := json.RawMessage(miniRaw)
		rpt.MiniRawResult = &raw
	}
	if stdRaw != nil {
		raw := json.RawMessage(stdRaw)
		rpt.StandardRawResult = &raw
	}
	return rpt, nil
}

func (r *ReportRepo) GetByIDForUser(ctx context.Context, id, userID string) (*model.Report, error) {
	rpt := &model.Report{}
	var miniRaw, stdRaw []byte
	err := r.DB.QueryRowContext(ctx, `
		SELECT id, reporter_id, image_url, location_text, latitude, longitude,
		       status, waste_type, severity, estimated_weight_kg, ai_confidence, ai_reasoning,
		       mini_raw_result, standard_raw_result, points_earned, reward_idr, created_at, updated_at
		FROM reports WHERE id = $1 AND reporter_id = $2`, id, userID,
	).Scan(&rpt.ID, &rpt.ReporterID, &rpt.ImageURL,
		&rpt.LocationText, &rpt.Latitude, &rpt.Longitude, &rpt.Status,
		&rpt.WasteType, &rpt.Severity, &rpt.EstimatedWeightKG, &rpt.AiConfidence, &rpt.AiReasoning,
		&miniRaw, &stdRaw, &rpt.PointsEarned, &rpt.RewardIDR, &rpt.CreatedAt, &rpt.UpdatedAt)
	if err != nil {
		return nil, err
	}
	if miniRaw != nil {
		raw := json.RawMessage(miniRaw)
		rpt.MiniRawResult = &raw
	}
	if stdRaw != nil {
		raw := json.RawMessage(stdRaw)
		rpt.StandardRawResult = &raw
	}
	return rpt, nil
}

func (r *ReportRepo) ListByUser(ctx context.Context, userID string, limit, offset int) ([]model.ReportSummary, error) {
	rows, err := r.DB.QueryContext(ctx, `
		SELECT id, location_text, status, waste_type, severity, points_earned, image_url,
		       to_char(created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
		FROM reports WHERE reporter_id = $1
		ORDER BY created_at DESC LIMIT $2 OFFSET $3`, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []model.ReportSummary
	for rows.Next() {
		var s model.ReportSummary
		if err := rows.Scan(&s.ID, &s.LocationText, &s.Status, &s.WasteType, &s.Severity,
			&s.Points, &s.ImageURL, &s.CreatedAt); err != nil {
			return nil, err
		}
		results = append(results, s)
	}
	return results, rows.Err()
}

func (r *ReportRepo) ListRecent(ctx context.Context, limit, offset int) ([]model.ReportSummary, error) {
	rows, err := r.DB.QueryContext(ctx, `
		SELECT id, location_text, status, waste_type, severity, points_earned, image_url,
		       to_char(created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
		FROM reports
		ORDER BY created_at DESC LIMIT $1 OFFSET $2`, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []model.ReportSummary
	for rows.Next() {
		var s model.ReportSummary
		if err := rows.Scan(&s.ID, &s.LocationText, &s.Status, &s.WasteType, &s.Severity,
			&s.Points, &s.ImageURL, &s.CreatedAt); err != nil {
			return nil, err
		}
		results = append(results, s)
	}
	return results, rows.Err()
}

func (r *ReportRepo) UpdateAIResult(ctx context.Context, id string, status, wasteType string, severity int,
	confidence float64, reasoning string, miniRaw, stdRaw json.RawMessage, points int, rewardIDR float64) error {
	_, err := r.DB.ExecContext(ctx, `
		UPDATE reports SET status=$1, waste_type=$2, severity=$3, ai_confidence=$4,
		       ai_reasoning=$5, mini_raw_result=$6, standard_raw_result=$7,
		       points_earned=$8, reward_idr=$9, updated_at=NOW()
		WHERE id=$10`,
		status, wasteType, severity, confidence, reasoning, miniRaw, stdRaw, points, rewardIDR, id)
	return err
}

func (r *ReportRepo) UpdateStatus(ctx context.Context, id, status string) error {
	_, err := r.DB.ExecContext(ctx, `UPDATE reports SET status=$1, updated_at=NOW() WHERE id=$2`, status, id)
	return err
}

func (r *ReportRepo) CountByUser(ctx context.Context, userID string) (int, error) {
	var count int
	err := r.DB.QueryRowContext(ctx, `SELECT COUNT(*) FROM reports WHERE reporter_id = $1`, userID).Scan(&count)
	return count, err
}

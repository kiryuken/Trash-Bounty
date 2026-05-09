package repository

import (
	"context"
	"database/sql"

	"trashbounty/internal/model"
)

type AchievementRepo struct {
	DB *sql.DB
}

func NewAchievementRepo(db *sql.DB) *AchievementRepo {
	return &AchievementRepo{DB: db}
}

// Grant idempotently grants an achievement (ON CONFLICT DO NOTHING)
func (r *AchievementRepo) Grant(ctx context.Context, userID, achievementType string) error {
	_, err := r.DB.ExecContext(ctx, `
		INSERT INTO achievements (user_id, type)
		VALUES ($1, $2)
		ON CONFLICT (user_id, type) DO NOTHING`, userID, achievementType)
	return err
}

// ListByUser returns all achievements for a user
func (r *AchievementRepo) ListByUser(ctx context.Context, userID string) ([]model.Achievement, error) {
	rows, err := r.DB.QueryContext(ctx, `
		SELECT id, user_id, type, earned_at
		FROM achievements WHERE user_id = $1
		ORDER BY earned_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []model.Achievement
	for rows.Next() {
		var a model.Achievement
		if err := rows.Scan(&a.ID, &a.UserID, &a.Type, &a.EarnedAt); err != nil {
			return nil, err
		}
		results = append(results, a)
	}
	return results, rows.Err()
}

// AllAchievementDefinitions returns the static list of all possible achievements with metadata
var AllAchievementDefinitions = []model.AchievementDTO{
	{Type: "first_report", Icon: "🏆", Name: "First Report"},
	{Type: "reports_10", Icon: "⭐", Name: "10 Reports"},
	{Type: "reports_25", Icon: "🎯", Name: "25 Reports"},
	{Type: "reports_50", Icon: "💎", Name: "50 Reports"},
	{Type: "reports_100", Icon: "👑", Name: "100 Reports"},
	{Type: "first_bounty", Icon: "🌟", Name: "First Bounty"},
	{Type: "bounties_10", Icon: "⭐", Name: "10 Bounties"},
	{Type: "bounties_25", Icon: "🎯", Name: "25 Bounties"},
	{Type: "bounties_50", Icon: "💎", Name: "50 Bounties"},
	{Type: "top_10_weekly", Icon: "🏆", Name: "Top 10 Weekly"},
	{Type: "top_10_monthly", Icon: "🏆", Name: "Top 10 Monthly"},
	{Type: "top_3_alltime", Icon: "👑", Name: "Top 3 All Time"},
	{Type: "points_1000", Icon: "⭐", Name: "10.000 Poin"},
	{Type: "points_5000", Icon: "💎", Name: "50.000 Poin"},
	{Type: "points_10000", Icon: "👑", Name: "100.000 Poin"},
}

// GetAchievementDTOs returns all achievements with unlocked status for a user
func (r *AchievementRepo) GetAchievementDTOs(ctx context.Context, userID string) ([]model.AchievementDTO, error) {
	earned, err := r.ListByUser(ctx, userID)
	if err != nil {
		return nil, err
	}

	earnedMap := make(map[string]string) // type -> earned_at
	for _, a := range earned {
		earnedMap[a.Type] = a.EarnedAt.Format("2006-01-02T15:04:05Z")
	}

	var result []model.AchievementDTO
	for _, def := range AllAchievementDefinitions {
		dto := model.AchievementDTO{
			Type: def.Type,
			Icon: def.Icon,
			Name: def.Name,
		}
		if earnedAt, ok := earnedMap[def.Type]; ok {
			dto.Unlocked = true
			dto.EarnedAt = &earnedAt
		}
		result = append(result, dto)
	}
	return result, nil
}

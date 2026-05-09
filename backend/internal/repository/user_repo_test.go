package repository

import (
	"context"
	"errors"
	"regexp"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
)

const getHistoryQuery = `
		SELECT * FROM (
			SELECT r.id, 'report' AS type, r.status::text,
			       r.location_text AS location, COALESCE(r.severity, 0) AS severity,
			       COALESCE(r.reward_idr, 0) AS reward,
			       r.points_earned,
			       to_char(r.created_at, 'DD Mon YYYY') AS date,
			       NULL::text AS duration,
			       to_char(r.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
			FROM reports r WHERE r.reporter_id = $1
			UNION ALL
			SELECT b.id, 'bounty' AS type, b.status::text,
			       b.location_text AS location, b.severity,
			       CASE WHEN b.status = 'completed' THEN b.reward_idr * 0.8 ELSE b.reward_idr END AS reward,
			       CASE WHEN b.status = 'completed' THEN (b.reward_points * 80) / 100 ELSE NULL END AS points_earned,
			       to_char(b.created_at, 'DD Mon YYYY') AS date,
			       CASE WHEN b.completed_at IS NOT NULL AND b.taken_at IS NOT NULL
			            THEN CAST(EXTRACT(EPOCH FROM (b.completed_at - b.taken_at)) / 60 AS INTEGER) || ' menit'
			            ELSE NULL END AS duration,
			       to_char(b.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
			FROM bounties b WHERE b.executor_id = $1
		) combined
		ORDER BY created_at DESC LIMIT $2 OFFSET $3`

func TestUserRepoGetHistory(t *testing.T) {
	t.Run("returns combined history with bounty reward projection", func(t *testing.T) {
		database, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("sqlmock.New() error = %v", err)
		}
		defer database.Close()

		repo := NewUserRepo(database)

		rows := sqlmock.NewRows([]string{
			"id",
			"type",
			"status",
			"location",
			"severity",
			"reward",
			"points_earned",
			"date",
			"duration",
			"created_at",
		}).
			AddRow("report-1", "report", "bounty_created", "Jalan Melati", 0, 2500.0, 25000, "29 Apr 2026", nil, "2026-04-29T10:00:00Z").
			AddRow("bounty-1", "bounty", "completed", "Jalan Mawar", 4, 8.0, 80, "28 Apr 2026", "15 menit", "2026-04-28T12:00:00Z").
			AddRow("bounty-2", "bounty", "taken", "Jalan Kenanga", 3, 10.0, nil, "27 Apr 2026", nil, "2026-04-27T09:00:00Z")

		mock.ExpectQuery(regexp.QuoteMeta(getHistoryQuery)).
			WithArgs("user-1", 20, 0).
			WillReturnRows(rows)

		history, err := repo.GetHistory(context.Background(), "user-1", 20, 0)
		if err != nil {
			t.Fatalf("GetHistory() unexpected error = %v", err)
		}

		if len(history) != 3 {
			t.Fatalf("GetHistory() len = %d, want 3", len(history))
		}

		if history[0].Type != "report" || history[0].Status != "bounty_created" {
			t.Fatalf("first item = %#v, want report history entry", history[0])
		}
		if history[0].Severity != 0 || history[0].RewardIDR != 2500.0 {
			t.Fatalf("report item severity/reward = (%d, %.1f), want (0, 2500.0)", history[0].Severity, history[0].RewardIDR)
		}
		if history[0].PointsEarned == nil || *history[0].PointsEarned != 25000 {
			t.Fatalf("report points_earned = %v, want 25000", history[0].PointsEarned)
		}
		if history[0].Duration != nil {
			t.Fatalf("report duration = %v, want nil", *history[0].Duration)
		}

		if history[1].Type != "bounty" || history[1].Status != "completed" {
			t.Fatalf("second item = %#v, want completed bounty entry", history[1])
		}
		if history[1].RewardIDR != 8.0 {
			t.Fatalf("completed bounty reward = %.1f, want 8.0", history[1].RewardIDR)
		}
		if history[1].PointsEarned == nil || *history[1].PointsEarned != 80 {
			t.Fatalf("completed bounty points_earned = %v, want 80", history[1].PointsEarned)
		}
		if history[1].Duration == nil || *history[1].Duration != "15 menit" {
			t.Fatalf("completed bounty duration = %v, want %q", history[1].Duration, "15 menit")
		}

		if history[2].Type != "bounty" || history[2].Status != "taken" {
			t.Fatalf("third item = %#v, want active bounty entry", history[2])
		}
		if history[2].RewardIDR != 10.0 {
			t.Fatalf("active bounty reward = %.1f, want 10.0", history[2].RewardIDR)
		}
		if history[2].PointsEarned != nil {
			t.Fatalf("active bounty points_earned = %v, want nil", history[2].PointsEarned)
		}
		if history[2].Duration != nil {
			t.Fatalf("active bounty duration = %v, want nil", history[2].Duration)
		}

		if err := mock.ExpectationsWereMet(); err != nil {
			t.Fatalf("unmet SQL expectations: %v", err)
		}
	})

	t.Run("returns query errors", func(t *testing.T) {
		database, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("sqlmock.New() error = %v", err)
		}
		defer database.Close()

		repo := NewUserRepo(database)
		wantErr := errors.New("db down")

		mock.ExpectQuery(regexp.QuoteMeta(getHistoryQuery)).
			WithArgs("user-1", 10, 5).
			WillReturnError(wantErr)

		_, err = repo.GetHistory(context.Background(), "user-1", 10, 5)
		if !errors.Is(err, wantErr) {
			t.Fatalf("GetHistory() error = %v, want %v", err, wantErr)
		}

		if err := mock.ExpectationsWereMet(); err != nil {
			t.Fatalf("unmet SQL expectations: %v", err)
		}
	})
}
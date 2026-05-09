package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"regexp"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"

	"trashbounty/internal/middleware"
	"trashbounty/internal/model"
	"trashbounty/internal/repository"
	"trashbounty/internal/service"
)

const getHistoryHandlerQuery = `
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

func TestProfileHandlerGetHistory(t *testing.T) {
	t.Run("returns history payload for the authenticated user", func(t *testing.T) {
		database, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("sqlmock.New() error = %v", err)
		}
		defer database.Close()

		userRepo := repository.NewUserRepo(database)
		profileSvc := service.NewProfileService(userRepo, nil)
		handler := NewProfileHandler(profileSvc)

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
			AddRow("bounty-1", "bounty", "completed", "Jalan Mawar", 4, 8.0, 80, "28 Apr 2026", "15 menit", "2026-04-28T12:00:00Z")

		mock.ExpectQuery(regexp.QuoteMeta(getHistoryHandlerQuery)).
			WithArgs("user-1", 2, 1).
			WillReturnRows(rows)

		req := httptest.NewRequest(http.MethodGet, "/users/me/history?limit=2&offset=1", nil)
		req = req.WithContext(context.WithValue(req.Context(), middleware.CtxUserID, "user-1"))
		rec := httptest.NewRecorder()

		handler.GetHistory(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("GetHistory() status = %d, want %d", rec.Code, http.StatusOK)
		}

		var payload struct {
			Success bool                `json:"success"`
			Data    []model.HistoryItem `json:"data"`
		}
		if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
			t.Fatalf("json.Unmarshal() error = %v", err)
		}

		if !payload.Success {
			t.Fatalf("response success = false, want true")
		}
		if len(payload.Data) != 2 {
			t.Fatalf("response item count = %d, want 2", len(payload.Data))
		}
		if payload.Data[0].ID != "report-1" || payload.Data[0].Type != "report" {
			t.Fatalf("first item = %#v, want report history item", payload.Data[0])
		}
		if payload.Data[1].RewardIDR != 8.0 {
			t.Fatalf("completed bounty reward = %.1f, want 8.0", payload.Data[1].RewardIDR)
		}
		if payload.Data[1].PointsEarned == nil || *payload.Data[1].PointsEarned != 80 {
			t.Fatalf("completed bounty points_earned = %v, want 80", payload.Data[1].PointsEarned)
		}

		if err := mock.ExpectationsWereMet(); err != nil {
			t.Fatalf("unmet SQL expectations: %v", err)
		}
	})

	t.Run("returns internal server error when history lookup fails", func(t *testing.T) {
		database, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("sqlmock.New() error = %v", err)
		}
		defer database.Close()

		userRepo := repository.NewUserRepo(database)
		profileSvc := service.NewProfileService(userRepo, nil)
		handler := NewProfileHandler(profileSvc)
		wantErr := errors.New("db down")

		mock.ExpectQuery(regexp.QuoteMeta(getHistoryHandlerQuery)).
			WithArgs("user-1", 20, 0).
			WillReturnError(wantErr)

		req := httptest.NewRequest(http.MethodGet, "/users/me/history", nil)
		req = req.WithContext(context.WithValue(req.Context(), middleware.CtxUserID, "user-1"))
		rec := httptest.NewRecorder()

		handler.GetHistory(rec, req)

		if rec.Code != http.StatusInternalServerError {
			t.Fatalf("GetHistory() status = %d, want %d", rec.Code, http.StatusInternalServerError)
		}

		var payload struct {
			Success bool   `json:"success"`
			Error   string `json:"error"`
		}
		if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
			t.Fatalf("json.Unmarshal() error = %v", err)
		}
		if payload.Success {
			t.Fatalf("response success = true, want false")
		}
		if payload.Error != wantErr.Error() {
			t.Fatalf("response error = %q, want %q", payload.Error, wantErr.Error())
		}

		if err := mock.ExpectationsWereMet(); err != nil {
			t.Fatalf("unmet SQL expectations: %v", err)
		}
	})
}
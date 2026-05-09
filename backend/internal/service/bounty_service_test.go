package service

import (
	"context"
	"database/sql"
	"regexp"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"

	"trashbounty/internal/repository"
)

func TestBountyServiceTake(t *testing.T) {
	t.Run("returns not found when bounty does not exist", func(t *testing.T) {
		database, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("sqlmock.New() error = %v", err)
		}
		defer database.Close()

		service := &BountyService{
			BountyRepo: repository.NewBountyRepo(database),
		}

		mock.ExpectQuery(regexp.QuoteMeta(`
		SELECT id, report_id, reporter_id, executor_id, location_text, address, waste_type, severity,
		       estimated_time_minutes, reward_points, reward_idr, latitude, longitude, image_url, status,
		       proof_image_url, taken_at, completed_at, created_at, updated_at
		FROM bounties WHERE id = $1`)).
			WithArgs("missing-bounty").
			WillReturnError(sql.ErrNoRows)

		err = service.Take(context.Background(), "missing-bounty", "executor-1")
		if err == nil || err.Error() != "bounty tidak ditemukan" {
			t.Fatalf("Take() error = %v, want %q", err, "bounty tidak ditemukan")
		}

		if err := mock.ExpectationsWereMet(); err != nil {
			t.Fatalf("unmet SQL expectations: %v", err)
		}
	})

	t.Run("rejects taking your own bounty", func(t *testing.T) {
		database, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("sqlmock.New() error = %v", err)
		}
		defer database.Close()

		service := &BountyService{
			BountyRepo: repository.NewBountyRepo(database),
		}

		createdAt := time.Unix(1700000000, 0)
		reporterID := "reporter-1"

		mock.ExpectQuery(regexp.QuoteMeta(`
		SELECT id, report_id, reporter_id, executor_id, location_text, address, waste_type, severity,
		       estimated_time_minutes, reward_points, reward_idr, latitude, longitude, image_url, status,
		       proof_image_url, taken_at, completed_at, created_at, updated_at
		FROM bounties WHERE id = $1`)).
			WithArgs("bounty-1").
			WillReturnRows(bountyDetailRows().AddRow(
				"bounty-1",
				"report-1",
				reporterID,
				nil,
				"Jalan Mawar",
				nil,
				"plastic",
				4,
				nil,
				100,
				10.0,
				-6.2,
				106.8,
				"https://example.com/report.jpg",
				"open",
				nil,
				nil,
				nil,
				createdAt,
				createdAt,
			))

		err = service.Take(context.Background(), "bounty-1", reporterID)
		if err == nil || err.Error() != "tidak bisa mengambil bounty sendiri" {
			t.Fatalf("Take() error = %v, want %q", err, "tidak bisa mengambil bounty sendiri")
		}

		if err := mock.ExpectationsWereMet(); err != nil {
			t.Fatalf("unmet SQL expectations: %v", err)
		}
	})

	t.Run("returns already taken when atomic take loses the race", func(t *testing.T) {
		database, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("sqlmock.New() error = %v", err)
		}
		defer database.Close()

		service := &BountyService{
			BountyRepo: repository.NewBountyRepo(database),
			NotifRepo:  repository.NewNotificationRepo(database),
		}

		mock.ExpectQuery(regexp.QuoteMeta(`
		SELECT id, report_id, reporter_id, executor_id, location_text, address, waste_type, severity,
		       estimated_time_minutes, reward_points, reward_idr, latitude, longitude, image_url, status,
		       proof_image_url, taken_at, completed_at, created_at, updated_at
		FROM bounties WHERE id = $1`)).
			WithArgs("bounty-1").
			WillReturnRows(bountyDetailRows().AddRow(
				"bounty-1",
				"report-1",
				"reporter-1",
				nil,
				"Jalan Mawar",
				nil,
				"plastic",
				4,
				nil,
				100,
				1000.0,
				-6.2,
				106.8,
				"https://example.com/report.jpg",
				"open",
				nil,
				nil,
				nil,
				time.Unix(1700000000, 0),
				time.Unix(1700000000, 0),
			))

		mock.ExpectExec(regexp.QuoteMeta(`
		UPDATE bounties SET executor_id=$1, status='taken', taken_at=NOW(), updated_at=NOW()
		WHERE id=$2 AND status='open'`)).
			WithArgs("executor-1", "bounty-1").
			WillReturnResult(sqlmock.NewResult(0, 0))

		err = service.Take(context.Background(), "bounty-1", "executor-1")
		if err == nil || err.Error() != "bounty sudah diambil" {
			t.Fatalf("Take() error = %v, want %q", err, "bounty sudah diambil")
		}

		if err := mock.ExpectationsWereMet(); err != nil {
			t.Fatalf("unmet SQL expectations: %v", err)
		}
	})

	t.Run("creates a notification when take succeeds", func(t *testing.T) {
		database, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("sqlmock.New() error = %v", err)
		}
		defer database.Close()

		service := &BountyService{
			BountyRepo: repository.NewBountyRepo(database),
			NotifRepo:  repository.NewNotificationRepo(database),
		}

		createdAt := time.Unix(1700000000, 0)

		mock.ExpectQuery(regexp.QuoteMeta(`
		SELECT id, report_id, reporter_id, executor_id, location_text, address, waste_type, severity,
		       estimated_time_minutes, reward_points, reward_idr, latitude, longitude, image_url, status,
		       proof_image_url, taken_at, completed_at, created_at, updated_at
		FROM bounties WHERE id = $1`)).
			WithArgs("bounty-1").
			WillReturnRows(bountyDetailRows().AddRow(
				"bounty-1",
				"report-1",
				"reporter-1",
				nil,
				"Jalan Mawar",
				nil,
				"plastic",
				4,
				nil,
				100,
				1000.0,
				-6.2,
				106.8,
				"https://example.com/report.jpg",
				"open",
				nil,
				nil,
				nil,
				createdAt,
				createdAt,
			))

		mock.ExpectExec(regexp.QuoteMeta(`
		UPDATE bounties SET executor_id=$1, status='taken', taken_at=NOW(), updated_at=NOW()
		WHERE id=$2 AND status='open'`)).
			WithArgs("executor-1", "bounty-1").
			WillReturnResult(sqlmock.NewResult(0, 1))

		mock.ExpectQuery(regexp.QuoteMeta(`
		INSERT INTO notifications (user_id, type, message)
		VALUES ($1, $2, $3)
		RETURNING id, created_at`)).
			WithArgs("reporter-1", "info", `Bounty di "Jalan Mawar" telah diambil oleh seseorang.`).
			WillReturnRows(sqlmock.NewRows([]string{"id", "created_at"}).AddRow("notif-1", createdAt))

		if err := service.Take(context.Background(), "bounty-1", "executor-1"); err != nil {
			t.Fatalf("Take() unexpected error = %v", err)
		}

		if err := mock.ExpectationsWereMet(); err != nil {
			t.Fatalf("unmet SQL expectations: %v", err)
		}
	})
}

func TestBountyServiceComplete(t *testing.T) {
	t.Run("rejects completion from a different executor", func(t *testing.T) {
		database, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("sqlmock.New() error = %v", err)
		}
		defer database.Close()

		service := &BountyService{
			BountyRepo: repository.NewBountyRepo(database),
		}

		createdAt := time.Unix(1700000000, 0)
		realExecutorID := "executor-1"

		mock.ExpectQuery(regexp.QuoteMeta(`
		SELECT id, report_id, reporter_id, executor_id, location_text, address, waste_type, severity,
		       estimated_time_minutes, reward_points, reward_idr, latitude, longitude, image_url, status,
		       proof_image_url, taken_at, completed_at, created_at, updated_at
		FROM bounties WHERE id = $1`)).
			WithArgs("bounty-1").
			WillReturnRows(bountyDetailRows().AddRow(
				"bounty-1",
				"report-1",
				"reporter-1",
				realExecutorID,
				"Jalan Mawar",
				nil,
				"plastic",
				4,
				nil,
				100,
				10.0,
				-6.2,
				106.8,
				"https://example.com/report.jpg",
				"taken",
				nil,
				createdAt,
				nil,
				createdAt,
				createdAt,
			))

		err = service.Complete(context.Background(), "bounty-1", "executor-2", "https://example.com/proof.jpg")
		if err == nil || err.Error() != "anda bukan executor bounty ini" {
			t.Fatalf("Complete() error = %v, want %q", err, "anda bukan executor bounty ini")
		}

		if err := mock.ExpectationsWereMet(); err != nil {
			t.Fatalf("unmet SQL expectations: %v", err)
		}
	})

	t.Run("rejects completion when bounty status is not active", func(t *testing.T) {
		database, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("sqlmock.New() error = %v", err)
		}
		defer database.Close()

		service := &BountyService{
			BountyRepo: repository.NewBountyRepo(database),
		}

		createdAt := time.Unix(1700000000, 0)
		executorID := "executor-1"

		mock.ExpectQuery(regexp.QuoteMeta(`
		SELECT id, report_id, reporter_id, executor_id, location_text, address, waste_type, severity,
		       estimated_time_minutes, reward_points, reward_idr, latitude, longitude, image_url, status,
		       proof_image_url, taken_at, completed_at, created_at, updated_at
		FROM bounties WHERE id = $1`)).
			WithArgs("bounty-1").
			WillReturnRows(bountyDetailRows().AddRow(
				"bounty-1",
				"report-1",
				"reporter-1",
				executorID,
				"Jalan Mawar",
				nil,
				"plastic",
				4,
				nil,
				100,
				10.0,
				-6.2,
				106.8,
				"https://example.com/report.jpg",
				"open",
				nil,
				nil,
				nil,
				createdAt,
				createdAt,
			))

		err = service.Complete(context.Background(), "bounty-1", executorID, "https://example.com/proof.jpg")
		if err == nil || err.Error() != "bounty tidak dalam status yang benar" {
			t.Fatalf("Complete() error = %v, want %q", err, "bounty tidak dalam status yang benar")
		}

		if err := mock.ExpectationsWereMet(); err != nil {
			t.Fatalf("unmet SQL expectations: %v", err)
		}
	})

	t.Run("returns an error when atomic complete loses the race", func(t *testing.T) {
		database, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("sqlmock.New() error = %v", err)
		}
		defer database.Close()

		service := &BountyService{
			BountyRepo: repository.NewBountyRepo(database),
			ReportRepo: repository.NewReportRepo(database),
		}

		executorID := "executor-1"
		createdAt := time.Unix(1700000000, 0)

		mock.ExpectQuery(regexp.QuoteMeta(`
		SELECT id, report_id, reporter_id, executor_id, location_text, address, waste_type, severity,
		       estimated_time_minutes, reward_points, reward_idr, latitude, longitude, image_url, status,
		       proof_image_url, taken_at, completed_at, created_at, updated_at
		FROM bounties WHERE id = $1`)).
			WithArgs("bounty-1").
			WillReturnRows(bountyDetailRows().AddRow(
				"bounty-1",
				"report-1",
				"reporter-1",
				executorID,
				"Jalan Mawar",
				nil,
				"plastic",
				4,
				nil,
				100,
				1000.0,
				-6.2,
				106.8,
				"https://example.com/report.jpg",
				"taken",
				nil,
				createdAt,
				nil,
				createdAt,
				createdAt,
			))

		mock.ExpectQuery(regexp.QuoteMeta(`
		SELECT id, reporter_id, image_url, location_text, latitude, longitude,
		       status, waste_type, severity, estimated_weight_kg, ai_confidence, ai_reasoning,
		       mini_raw_result, standard_raw_result, points_earned, reward_idr, created_at, updated_at
		FROM reports WHERE id = $1`)).
			WithArgs("report-1").
			WillReturnRows(reportDetailRows().AddRow(
				"report-1",
				"reporter-1",
				"https://example.com/report.jpg",
				"Jalan Mawar",
				-6.2,
				106.8,
				"bounty_created",
				nil,
				nil,
				nil,
				nil,
				nil,
				nil,
				nil,
				nil,
				nil,
				createdAt,
				createdAt,
			))

		mock.ExpectExec(regexp.QuoteMeta(`
		UPDATE bounties SET proof_image_url=$1, status='completed', completed_at=NOW(), updated_at=NOW()
		WHERE id=$2 AND executor_id=$3 AND status IN ('taken', 'in_progress')`)).
			WithArgs("https://example.com/proof.jpg", "bounty-1", executorID).
			WillReturnResult(sqlmock.NewResult(0, 0))

		err = service.Complete(context.Background(), "bounty-1", executorID, "https://example.com/proof.jpg")
		if err == nil || err.Error() != "bounty tidak lagi dalam status yang benar" {
			t.Fatalf("Complete() error = %v, want %q", err, "bounty tidak lagi dalam status yang benar")
		}

		if err := mock.ExpectationsWereMet(); err != nil {
			t.Fatalf("unmet SQL expectations: %v", err)
		}
	})

	t.Run("completes the bounty and rewards both users", func(t *testing.T) {
		database, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("sqlmock.New() error = %v", err)
		}
		defer database.Close()

		service := &BountyService{
			BountyRepo: repository.NewBountyRepo(database),
			UserRepo:   repository.NewUserRepo(database),
			NotifRepo:  repository.NewNotificationRepo(database),
			TxRepo:     repository.NewTransactionRepo(database),
			ReportRepo: repository.NewReportRepo(database),
		}

		executorID := "executor-1"
		reporterID := "reporter-1"
		proofURL := "https://example.com/proof.jpg"
		createdAt := time.Unix(1700000000, 0)

		mock.ExpectQuery(regexp.QuoteMeta(`
		SELECT id, report_id, reporter_id, executor_id, location_text, address, waste_type, severity,
		       estimated_time_minutes, reward_points, reward_idr, latitude, longitude, image_url, status,
		       proof_image_url, taken_at, completed_at, created_at, updated_at
		FROM bounties WHERE id = $1`)).
			WithArgs("bounty-1").
			WillReturnRows(bountyDetailRows().AddRow(
				"bounty-1",
				"report-1",
				reporterID,
				executorID,
				"Jalan Mawar",
				nil,
				"plastic",
				4,
				nil,
				100,
				10.0,
				-6.2,
				106.8,
				"https://example.com/report.jpg",
				"taken",
				nil,
				createdAt,
				nil,
				createdAt,
				createdAt,
			))

		mock.ExpectQuery(regexp.QuoteMeta(`
		SELECT id, reporter_id, image_url, location_text, latitude, longitude,
		       status, waste_type, severity, estimated_weight_kg, ai_confidence, ai_reasoning,
		       mini_raw_result, standard_raw_result, points_earned, reward_idr, created_at, updated_at
		FROM reports WHERE id = $1`)).
			WithArgs("report-1").
			WillReturnRows(reportDetailRows().AddRow(
				"report-1",
				reporterID,
				"https://example.com/report.jpg",
				"Jalan Mawar",
				-6.2,
				106.8,
				"bounty_created",
				nil,
				nil,
				nil,
				nil,
				nil,
				nil,
				nil,
				nil,
				nil,
				createdAt,
				createdAt,
			))

		mock.ExpectExec(regexp.QuoteMeta(`
		UPDATE bounties SET proof_image_url=$1, status='completed', completed_at=NOW(), updated_at=NOW()
		WHERE id=$2 AND executor_id=$3 AND status IN ('taken', 'in_progress')`)).
			WithArgs(proofURL, "bounty-1", executorID).
			WillReturnResult(sqlmock.NewResult(0, 1))

		mock.ExpectExec(regexp.QuoteMeta(`UPDATE reports SET status=$1, updated_at=NOW() WHERE id=$2`)).
			WithArgs("completed", "report-1").
			WillReturnResult(sqlmock.NewResult(0, 1))

		mock.ExpectExec(regexp.QuoteMeta(`UPDATE users SET points = points + $1, updated_at=NOW() WHERE id = $2`)).
			WithArgs(80, executorID).
			WillReturnResult(sqlmock.NewResult(0, 1))

		mock.ExpectExec(regexp.QuoteMeta(`UPDATE users SET wallet_balance = wallet_balance + $1, updated_at=NOW() WHERE id = $2`)).
			WithArgs(8.0, executorID).
			WillReturnResult(sqlmock.NewResult(0, 1))

		mock.ExpectQuery(regexp.QuoteMeta(`
		INSERT INTO transactions (user_id, type, status, points_delta, idr_delta, reference_id, description)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, created_at`)).
			WithArgs(executorID, "points_earned_bounty", "completed", 80, 8.0, "bounty-1", "Reward bounty: Jalan Mawar").
			WillReturnRows(sqlmock.NewRows([]string{"id", "created_at"}).AddRow("tx-executor", createdAt))

		mock.ExpectExec(regexp.QuoteMeta(`UPDATE users SET points = points + $1, updated_at=NOW() WHERE id = $2`)).
			WithArgs(20, reporterID).
			WillReturnResult(sqlmock.NewResult(0, 1))

		mock.ExpectExec(regexp.QuoteMeta(`UPDATE users SET wallet_balance = wallet_balance + $1, updated_at=NOW() WHERE id = $2`)).
			WithArgs(2.0, reporterID).
			WillReturnResult(sqlmock.NewResult(0, 1))

		mock.ExpectQuery(regexp.QuoteMeta(`
		INSERT INTO transactions (user_id, type, status, points_delta, idr_delta, reference_id, description)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, created_at`)).
			WithArgs(reporterID, "points_bonus", "completed", 20, 2.0, "bounty-1", "Bonus reporter bounty: Jalan Mawar").
			WillReturnRows(sqlmock.NewRows([]string{"id", "created_at"}).AddRow("tx-reporter", createdAt))

		mock.ExpectQuery(regexp.QuoteMeta(`
		INSERT INTO notifications (user_id, type, message)
		VALUES ($1, $2, $3)
		RETURNING id, created_at`)).
			WithArgs(executorID, "reward", `Bounty di "Jalan Mawar" selesai! Anda mendapat 80 points.`).
			WillReturnRows(sqlmock.NewRows([]string{"id", "created_at"}).AddRow("notif-executor", createdAt))

		mock.ExpectQuery(regexp.QuoteMeta(`
		INSERT INTO notifications (user_id, type, message)
		VALUES ($1, $2, $3)
		RETURNING id, created_at`)).
			WithArgs(reporterID, "reward", `Bounty di "Jalan Mawar" telah diselesaikan. Anda mendapat bonus 20 points!`).
			WillReturnRows(sqlmock.NewRows([]string{"id", "created_at"}).AddRow("notif-reporter", createdAt))

		mock.ExpectQuery(regexp.QuoteMeta(`SELECT COUNT(*) FROM bounties WHERE executor_id = $1 AND status = 'completed'`)).
			WithArgs(executorID).
			WillReturnError(sql.ErrNoRows)

		mock.ExpectQuery(regexp.QuoteMeta(`
		SELECT id, email, password_hash, name, avatar_url, role, points, wallet_balance,
		       rank, is_public_profile, location_sharing, two_factor_enabled, created_at, updated_at
		FROM users WHERE id = $1`)).
			WithArgs(executorID).
			WillReturnError(sql.ErrNoRows)

		mock.ExpectQuery(regexp.QuoteMeta(`
		SELECT id, email, password_hash, name, avatar_url, role, points, wallet_balance,
		       rank, is_public_profile, location_sharing, two_factor_enabled, created_at, updated_at
		FROM users WHERE id = $1`)).
			WithArgs(reporterID).
			WillReturnError(sql.ErrNoRows)

		if err := service.Complete(context.Background(), "bounty-1", executorID, proofURL); err != nil {
			t.Fatalf("Complete() unexpected error = %v", err)
		}

		if err := mock.ExpectationsWereMet(); err != nil {
			t.Fatalf("unmet SQL expectations: %v", err)
		}
	})
}

func bountyDetailRows() *sqlmock.Rows {
	return sqlmock.NewRows([]string{
		"id",
		"report_id",
		"reporter_id",
		"executor_id",
		"location_text",
		"address",
		"waste_type",
		"severity",
		"estimated_time_minutes",
		"reward_points",
		"reward_idr",
		"latitude",
		"longitude",
		"image_url",
		"status",
		"proof_image_url",
		"taken_at",
		"completed_at",
		"created_at",
		"updated_at",
	})
}

func reportDetailRows() *sqlmock.Rows {
	return sqlmock.NewRows([]string{
		"id",
		"reporter_id",
		"image_url",
		"location_text",
		"latitude",
		"longitude",
		"status",
		"waste_type",
		"severity",
		"estimated_weight_kg",
		"ai_confidence",
		"ai_reasoning",
		"mini_raw_result",
		"standard_raw_result",
		"points_earned",
		"reward_idr",
		"created_at",
		"updated_at",
	})
}
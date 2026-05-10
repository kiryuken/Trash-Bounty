package service

import (
	"context"
	"regexp"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"

	"trashbounty/internal/repository"
)

func TestReportServiceEscalateToAgency(t *testing.T) {
	t.Run("rejects empty urgency reason", func(t *testing.T) {
		service := &ReportService{}

		err := service.EscalateToAgency(context.Background(), "report-1", "user-1", "   ")
		if err != ErrReportEscalationReasonRequired {
			t.Fatalf("EscalateToAgency() error = %v, want %v", err, ErrReportEscalationReasonRequired)
		}
	})

	t.Run("rejects reports that are still being analyzed", func(t *testing.T) {
		database, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("sqlmock.New() error = %v", err)
		}
		defer database.Close()

		service := &ReportService{
			ReportRepo: repository.NewReportRepo(database),
		}

		createdAt := time.Unix(1700000000, 0)

		mock.ExpectQuery(regexp.QuoteMeta(`
		SELECT id, reporter_id, image_url, location_text, latitude, longitude,
		       status, waste_type, severity, estimated_weight_kg, ai_confidence, ai_reasoning,
		       mini_raw_result, standard_raw_result, points_earned, reward_idr,
		       agency_escalation_status, agency_escalation_reason, agency_escalation_requested_at,
		       agency_escalation_sent_at, agency_escalation_failed_at, agency_escalation_last_error,
		       created_at, updated_at
		FROM reports WHERE id = $1 AND reporter_id = $2`)).
			WithArgs("report-1", "user-1").
			WillReturnRows(reportEscalationDetailRows().AddRow(
				"report-1",
				"user-1",
				"/uploads/reports/report-1.jpg",
				"Jalan Melati",
				-6.2,
				106.8,
				"ai_analyzing",
				"unknown",
				nil,
				nil,
				nil,
				nil,
				nil,
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

		err = service.EscalateToAgency(context.Background(), "report-1", "user-1", "Sampah menutup akses warga")
		if err != ErrReportEscalationUnavailable {
			t.Fatalf("EscalateToAgency() error = %v, want %v", err, ErrReportEscalationUnavailable)
		}

		if err := mock.ExpectationsWereMet(); err != nil {
			t.Fatalf("unmet SQL expectations: %v", err)
		}
	})

	t.Run("rejects reports that were already sent to the agency", func(t *testing.T) {
		database, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("sqlmock.New() error = %v", err)
		}
		defer database.Close()

		service := &ReportService{
			ReportRepo: repository.NewReportRepo(database),
		}

		createdAt := time.Unix(1700000000, 0)
		sentAt := createdAt.Add(2 * time.Hour)

		mock.ExpectQuery(regexp.QuoteMeta(`
		SELECT id, reporter_id, image_url, location_text, latitude, longitude,
		       status, waste_type, severity, estimated_weight_kg, ai_confidence, ai_reasoning,
		       mini_raw_result, standard_raw_result, points_earned, reward_idr,
		       agency_escalation_status, agency_escalation_reason, agency_escalation_requested_at,
		       agency_escalation_sent_at, agency_escalation_failed_at, agency_escalation_last_error,
		       created_at, updated_at
		FROM reports WHERE id = $1 AND reporter_id = $2`)).
			WithArgs("report-1", "user-1").
			WillReturnRows(reportEscalationDetailRows().AddRow(
				"report-1",
				"user-1",
				"/uploads/reports/report-1.jpg",
				"Jalan Melati",
				-6.2,
				106.8,
				"approved",
				"plastic",
				8,
				12.5,
				0.93,
				"Sampah menumpuk dekat saluran air.",
				nil,
				nil,
				120,
				12.0,
				"sent",
				"Butuh penanganan cepat",
				createdAt,
				sentAt,
				nil,
				nil,
				createdAt,
				createdAt,
			))

		err = service.EscalateToAgency(context.Background(), "report-1", "user-1", "Sampah menutup akses warga")
		if err != ErrReportEscalationSent {
			t.Fatalf("EscalateToAgency() error = %v, want %v", err, ErrReportEscalationSent)
		}

		if err := mock.ExpectationsWereMet(); err != nil {
			t.Fatalf("unmet SQL expectations: %v", err)
		}
	})
}

func reportEscalationDetailRows() *sqlmock.Rows {
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
		"agency_escalation_status",
		"agency_escalation_reason",
		"agency_escalation_requested_at",
		"agency_escalation_sent_at",
		"agency_escalation_failed_at",
		"agency_escalation_last_error",
		"created_at",
		"updated_at",
	})
}
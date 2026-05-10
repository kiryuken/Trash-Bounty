package repository

import (
	"context"
	"regexp"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
)

func TestReportRepoAgencyEscalation(t *testing.T) {
	t.Run("requests agency escalation as pending", func(t *testing.T) {
		database, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("sqlmock.New() error = %v", err)
		}
		defer database.Close()

		repo := NewReportRepo(database)

		mock.ExpectExec(regexp.QuoteMeta(`
		UPDATE reports
		SET agency_escalation_status='pending',
		    agency_escalation_reason=$1,
		    agency_escalation_requested_at=NOW(),
		    agency_escalation_sent_at=NULL,
		    agency_escalation_failed_at=NULL,
		    agency_escalation_last_error=NULL,
		    updated_at=NOW()
		WHERE id=$2
		  AND (agency_escalation_status IS NULL OR agency_escalation_status='failed')`)).
			WithArgs("Saluran tertutup sampah dan rawan banjir", "report-1").
			WillReturnResult(sqlmock.NewResult(0, 1))

		ok, err := repo.RequestAgencyEscalation(context.Background(), "report-1", "Saluran tertutup sampah dan rawan banjir")
		if err != nil {
			t.Fatalf("RequestAgencyEscalation() unexpected error = %v", err)
		}
		if !ok {
			t.Fatalf("RequestAgencyEscalation() ok = false, want true")
		}

		if err := mock.ExpectationsWereMet(); err != nil {
			t.Fatalf("unmet SQL expectations: %v", err)
		}
	})

	t.Run("marks agency escalation as sent", func(t *testing.T) {
		database, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("sqlmock.New() error = %v", err)
		}
		defer database.Close()

		repo := NewReportRepo(database)

		mock.ExpectExec(regexp.QuoteMeta(`
		UPDATE reports
		SET agency_escalation_status='sent',
		    agency_escalation_sent_at=NOW(),
		    agency_escalation_failed_at=NULL,
		    agency_escalation_last_error=NULL,
		    updated_at=NOW()
		WHERE id=$1`)).
			WithArgs("report-1").
			WillReturnResult(sqlmock.NewResult(0, 1))

		if err := repo.MarkAgencyEscalationSent(context.Background(), "report-1"); err != nil {
			t.Fatalf("MarkAgencyEscalationSent() unexpected error = %v", err)
		}

		if err := mock.ExpectationsWereMet(); err != nil {
			t.Fatalf("unmet SQL expectations: %v", err)
		}
	})

	t.Run("marks agency escalation as failed", func(t *testing.T) {
		database, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("sqlmock.New() error = %v", err)
		}
		defer database.Close()

		repo := NewReportRepo(database)

		mock.ExpectExec(regexp.QuoteMeta(`
		UPDATE reports
		SET agency_escalation_status='failed',
		    agency_escalation_failed_at=NOW(),
		    agency_escalation_last_error=$1,
		    updated_at=NOW()
		WHERE id=$2`)).
			WithArgs("smtp down", "report-1").
			WillReturnResult(sqlmock.NewResult(0, 1))

		if err := repo.MarkAgencyEscalationFailed(context.Background(), "report-1", "smtp down"); err != nil {
			t.Fatalf("MarkAgencyEscalationFailed() unexpected error = %v", err)
		}

		if err := mock.ExpectationsWereMet(); err != nil {
			t.Fatalf("unmet SQL expectations: %v", err)
		}
	})
}
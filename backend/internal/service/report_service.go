package service

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"

	"trashbounty/internal/model"
	"trashbounty/internal/repository"
	"trashbounty/internal/service/ai"
)

var (
	ErrReportEscalationReasonRequired = errors.New("alasan urgensi wajib diisi")
	ErrReportEscalationNotFound       = errors.New("laporan tidak ditemukan")
	ErrReportEscalationUnavailable    = errors.New("laporan belum selesai dianalisis")
	ErrReportEscalationPending        = errors.New("laporan sedang dikirim ke dinas")
	ErrReportEscalationSent           = errors.New("laporan sudah dikirim ke dinas")
)

type ReportService struct {
	ReportRepo      *repository.ReportRepo
	BountyRepo      *repository.BountyRepo
	UserRepo        *repository.UserRepo
	NotifRepo       *repository.NotificationRepo
	TxRepo          *repository.TransactionRepo
	AchievementRepo *repository.AchievementRepo
	AI              *ai.Orchestrator
	AgentsInternalURL    string
	AgentsInternalSecret string
	HTTPClient           *http.Client
}

func NewReportService(
	reportRepo *repository.ReportRepo,
	bountyRepo *repository.BountyRepo,
	userRepo *repository.UserRepo,
	notifRepo *repository.NotificationRepo,
	txRepo *repository.TransactionRepo,
	achievementRepo *repository.AchievementRepo,
	aiOrch *ai.Orchestrator,
	agentsInternalURL string,
	agentsInternalSecret string,
) *ReportService {
	return &ReportService{
		ReportRepo:      reportRepo,
		BountyRepo:      bountyRepo,
		UserRepo:        userRepo,
		NotifRepo:       notifRepo,
		TxRepo:          txRepo,
		AchievementRepo: achievementRepo,
		AI:              aiOrch,
		AgentsInternalURL:    strings.TrimRight(agentsInternalURL, "/"),
		AgentsInternalSecret: agentsInternalSecret,
		HTTPClient:           &http.Client{Timeout: 5 * time.Second},
	}
}

func (s *ReportService) Create(ctx context.Context, userID, imageURL string, lat, lng float64, locationText string) (*model.Report, error) {
	report := &model.Report{
		ReporterID:   userID,
		ImageURL:     imageURL,
		Latitude:     lat,
		Longitude:    lng,
		LocationText: locationText,
	}

	if err := s.ReportRepo.Create(ctx, report); err != nil {
		return nil, err
	}

	// Run AI analysis in background with 2-minute timeout
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
		defer cancel()
		s.processAI(ctx, report)
	}()

	return report, nil
}

func (s *ReportService) processAI(ctx context.Context, report *model.Report) {
	// Update status to ai_analyzing
	_ = s.ReportRepo.UpdateStatus(ctx, report.ID, "ai_analyzing")

	// Run AI in a channel so we can respect the context timeout
	type aiResultWrapper struct {
		result *model.AIResult
		mini   []byte
		std    []byte
		err    error
	}
	ch := make(chan aiResultWrapper, 1)
	go func() {
		result, miniRaw, stdRaw, err := s.AI.Process(report.ImageURL, report.LocationText, "", report.LocationText)
		ch <- aiResultWrapper{result, miniRaw, stdRaw, err}
	}()

	select {
	case <-ctx.Done():
		log.Printf("[AI] Timeout processing report %s", report.ID)
		_ = s.ReportRepo.UpdateStatus(ctx, report.ID, "rejected")
		_ = s.NotifRepo.Create(ctx, &model.Notification{
			UserID:  report.ReporterID,
			Type:    "warning",
			Message: "Analisis AI gagal (timeout), coba upload ulang foto.",
		})
		s.sendTelegramNotificationAsync(report.ReporterID, fmt.Sprintf("Laporan %s untuk lokasi \"%s\" gagal diproses karena timeout. Coba kirim ulang lalu cek dengan /reportstatus %s.", report.ID, report.LocationText, report.ID))
		return
	case res := <-ch:
		if res.err != nil {
			log.Printf("[AI] Error processing report %s: %v", report.ID, res.err)
			_ = s.ReportRepo.UpdateStatus(ctx, report.ID, "rejected")
			_ = s.NotifRepo.Create(ctx, &model.Notification{
				UserID:  report.ReporterID,
				Type:    "warning",
				Message: "Analisis AI gagal, coba upload ulang foto.",
			})
			s.sendTelegramNotificationAsync(report.ReporterID, fmt.Sprintf("Laporan %s untuk lokasi \"%s\" gagal dianalisis. Coba kirim ulang lalu cek dengan /reportstatus %s.", report.ID, report.LocationText, report.ID))
			return
		}
		s.handleAIResult(ctx, report, res.result, res.mini, res.std)
	}
}

func (s *ReportService) handleAIResult(ctx context.Context, report *model.Report, result *model.AIResult, miniRaw, stdRaw []byte) {
	status := "rejected"
	if result.Approved {
		status = "approved"
	}

	if err := s.ReportRepo.UpdateAIResult(
		ctx, report.ID, status, result.WasteType, result.Severity,
		result.Confidence, result.Reasoning, miniRaw, stdRaw, result.RewardPoints, result.RewardIDR,
	); err != nil {
		log.Printf("[AI] Error updating report %s: %v", report.ID, err)
		return
	}

	if result.Approved {
		// Award points to reporter
		_ = s.UserRepo.AddPoints(ctx, report.ReporterID, result.RewardPoints)
		_ = s.UserRepo.AddWallet(ctx, report.ReporterID, result.RewardIDR)

		// Create transaction
		desc := fmt.Sprintf("Points dari laporan: %s", report.LocationText)
		_ = s.TxRepo.Create(ctx, &model.Transaction{
			UserID:      report.ReporterID,
			Type:        "points_earned_report",
			Status:      "completed",
			PointsDelta: &result.RewardPoints,
			IDRDelta:    &result.RewardIDR,
			ReferenceID: &report.ID,
			Description: &desc,
		})

		// Auto-create bounty
		bounty := &model.Bounty{
			ReportID:     report.ID,
			ReporterID:   report.ReporterID,
			LocationText: report.LocationText,
			WasteType:    result.WasteType,
			Severity:     result.Severity,
			RewardPoints: result.RewardPoints,
			RewardIDR:    result.RewardIDR,
			Latitude:     report.Latitude,
			Longitude:    report.Longitude,
			ImageURL:     report.ImageURL,
		}
		if err := s.BountyRepo.Create(ctx, bounty); err != nil {
			log.Printf("[AI] Error creating bounty for report %s: %v", report.ID, err)
		} else {
			_ = s.ReportRepo.UpdateStatus(ctx, report.ID, "bounty_created")
		}

		// Notify reporter
		_ = s.NotifRepo.Create(ctx, &model.Notification{
			UserID:  report.ReporterID,
			Type:    "success",
			Message: fmt.Sprintf("Laporan di \"%s\" disetujui. Anda mendapat %d points!", report.LocationText, result.RewardPoints),
		})
		s.sendTelegramNotificationAsync(
			report.ReporterID,
			fmt.Sprintf(
				"Laporan %s di \"%s\" disetujui Lumi. Kamu mendapat %d points dan bounty sudah dibuat. Gunakan /reportstatus %s untuk detail.",
				report.ID,
				report.LocationText,
				result.RewardPoints,
				report.ID,
			),
		)

		// Check and award achievements
		s.checkReportAchievements(ctx, report.ReporterID)
		s.checkPointsAchievements(ctx, report.ReporterID)
	} else {
		_ = s.NotifRepo.Create(ctx, &model.Notification{
			UserID:  report.ReporterID,
			Type:    "warning",
			Message: fmt.Sprintf("Laporan di \"%s\" ditolak. Alasan: %s", report.LocationText, result.Reasoning),
		})
		s.sendTelegramNotificationAsync(
			report.ReporterID,
			fmt.Sprintf(
				"Laporan %s di \"%s\" ditolak Lumi. Alasan: %s. Gunakan /reportstatus %s untuk detail.",
				report.ID,
				report.LocationText,
				result.Reasoning,
				report.ID,
			),
		)
	}
}

func (s *ReportService) sendTelegramNotificationAsync(userID, message string) {
	if s.AgentsInternalURL == "" || s.AgentsInternalSecret == "" || userID == "" || message == "" {
		return
	}

	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		chatID, err := s.UserRepo.GetTelegramChatID(ctx, userID)
		if err != nil || chatID == nil || *chatID == "" {
			return
		}

		payload, err := json.Marshal(map[string]string{
			"telegram_chat_id": *chatID,
			"message":          message,
		})
		if err != nil {
			return
		}

		req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.AgentsInternalURL+"/internal/notify", bytes.NewReader(payload))
		if err != nil {
			return
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Internal-Secret", s.AgentsInternalSecret)

		resp, err := s.HTTPClient.Do(req)
		if err != nil {
			return
		}
		defer resp.Body.Close()
	}()
}

func (s *ReportService) GetByID(ctx context.Context, id string) (*model.Report, error) {
	return s.ReportRepo.GetByID(ctx, id)
}

func (s *ReportService) EscalateToAgency(ctx context.Context, reportID, userID, reason string) error {
	reason = strings.TrimSpace(reason)
	if reason == "" {
		return ErrReportEscalationReasonRequired
	}

	report, err := s.ReportRepo.GetByIDForUser(ctx, reportID, userID)
	if err != nil {
		return ErrReportEscalationNotFound
	}
	if !isAgencyEscalationEligible(report.Status) {
		return ErrReportEscalationUnavailable
	}
	if report.AgencyEscalationStatus != nil {
		switch *report.AgencyEscalationStatus {
		case "pending":
			return ErrReportEscalationPending
		case "sent":
			return ErrReportEscalationSent
		}
	}

	reporter, err := s.UserRepo.GetByID(ctx, userID)
	if err != nil {
		return err
	}

	requested, err := s.ReportRepo.RequestAgencyEscalation(ctx, reportID, reason)
	if err != nil {
		return err
	}
	if !requested {
		current, currentErr := s.ReportRepo.GetByIDForUser(ctx, reportID, userID)
		if currentErr == nil && current.AgencyEscalationStatus != nil {
			switch *current.AgencyEscalationStatus {
			case "pending":
				return ErrReportEscalationPending
			case "sent":
				return ErrReportEscalationSent
			}
		}
		return ErrReportEscalationPending
	}

	now := time.Now().UTC()
	report.AgencyEscalationStatus = stringPtr("pending")
	report.AgencyEscalationReason = stringPtr(reason)
	report.AgencyEscalationRequestedAt = &now
	report.AgencyEscalationSentAt = nil
	report.AgencyEscalationFailedAt = nil
	report.AgencyEscalationLastError = nil

	s.sendAgencyEscalationAsync(report, reporter, reason, now)
	return nil
}

func (s *ReportService) GetByIDForUser(ctx context.Context, id, userID string) (*model.Report, error) {
	return s.ReportRepo.GetByIDForUser(ctx, id, userID)
}

func (s *ReportService) ListByUser(ctx context.Context, userID string, limit, offset int) ([]model.ReportSummary, error) {
	return s.ReportRepo.ListByUser(ctx, userID, limit, offset)
}

func (s *ReportService) ListRecent(ctx context.Context, limit, offset int) ([]model.ReportSummary, error) {
	return s.ReportRepo.ListRecent(ctx, limit, offset)
}

func (s *ReportService) sendAgencyEscalationAsync(report *model.Report, reporter *model.User, reason string, requestedAt time.Time) {
	if report == nil || reporter == nil {
		return
	}

	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		fail := func(message string) {
			if message == "" {
				message = "gagal mengirim email ke dinas"
			}
			_ = s.ReportRepo.MarkAgencyEscalationFailed(ctx, report.ID, message)
			_ = s.NotifRepo.Create(ctx, &model.Notification{
				UserID:  report.ReporterID,
				Type:    "warning",
				Message: fmt.Sprintf("Laporan ke dinas untuk \"%s\" gagal dikirim. %s", report.LocationText, message),
			})
		}

		if s.AgentsInternalURL == "" || s.AgentsInternalSecret == "" {
			fail("integrasi email dinas belum dikonfigurasi")
			return
		}

		payload, err := json.Marshal(map[string]any{
			"report_id":           report.ID,
			"report_status":       report.Status,
			"reporter_id":         report.ReporterID,
			"reporter_name":       reporter.Name,
			"reporter_email":      reporter.Email,
			"location_text":       report.LocationText,
			"latitude":            report.Latitude,
			"longitude":           report.Longitude,
			"urgency_reason":      reason,
			"requested_at":        requestedAt.Format(time.RFC3339),
			"image_url":           report.ImageURL,
			"waste_type":          report.WasteType,
			"severity":            report.Severity,
			"ai_reasoning":        report.AiReasoning,
			"ai_confidence":       report.AiConfidence,
			"estimated_weight_kg": report.EstimatedWeightKG,
			"report_created_at":   report.CreatedAt.Format(time.RFC3339),
		})
		if err != nil {
			fail("payload email dinas tidak valid")
			return
		}

		req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.AgentsInternalURL+"/internal/agency-escalations", bytes.NewReader(payload))
		if err != nil {
			fail("request email dinas tidak dapat dibuat")
			return
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Internal-Secret", s.AgentsInternalSecret)

		client := &http.Client{Timeout: 30 * time.Second}
		resp, err := client.Do(req)
		if err != nil {
			fail("layanan email dinas tidak merespons")
			return
		}
		defer resp.Body.Close()

		if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
			message := fmt.Sprintf("layanan email dinas mengembalikan status %d", resp.StatusCode)
			body, readErr := io.ReadAll(io.LimitReader(resp.Body, 512))
			if readErr == nil {
				trimmed := strings.TrimSpace(string(body))
				if trimmed != "" {
					message = trimmed
				}
			}
			fail(message)
			return
		}

		if err := s.ReportRepo.MarkAgencyEscalationSent(ctx, report.ID); err != nil {
			log.Printf("[AgencyEscalation] failed to mark sent for report %s: %v", report.ID, err)
			return
		}
		_ = s.NotifRepo.Create(ctx, &model.Notification{
			UserID:  report.ReporterID,
			Type:    "info",
			Message: fmt.Sprintf("Laporan di \"%s\" sudah diteruskan ke dinas lingkungan hidup.", report.LocationText),
		})
	}()
}

func isAgencyEscalationEligible(status string) bool {
	switch status {
	case "approved", "bounty_created", "completed", "rejected":
		return true
	default:
		return false
	}
}

func stringPtr(value string) *string {
	return &value
}

func (s *ReportService) checkReportAchievements(ctx context.Context, userID string) {
	count, err := s.ReportRepo.CountByUser(ctx, userID)
	if err != nil {
		return
	}
	thresholds := map[int]string{
		1: "first_report", 10: "reports_10", 25: "reports_25",
		50: "reports_50", 100: "reports_100",
	}
	for threshold, aType := range thresholds {
		if count >= threshold {
			_ = s.AchievementRepo.Grant(ctx, userID, aType)
		}
	}
}

func (s *ReportService) checkPointsAchievements(ctx context.Context, userID string) {
	user, err := s.UserRepo.GetByID(ctx, userID)
	if err != nil {
		return
	}
	thresholds := map[int]string{
		10000: "points_1000", 50000: "points_5000", 100000: "points_10000",
	}
	for threshold, aType := range thresholds {
		if user.Points >= threshold {
			_ = s.AchievementRepo.Grant(ctx, userID, aType)
		}
	}
}

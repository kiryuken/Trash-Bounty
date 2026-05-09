package service

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"trashbounty/internal/model"
	"trashbounty/internal/repository"
	"trashbounty/internal/service/ai"
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

func (s *ReportService) GetByIDForUser(ctx context.Context, id, userID string) (*model.Report, error) {
	return s.ReportRepo.GetByIDForUser(ctx, id, userID)
}

func (s *ReportService) ListByUser(ctx context.Context, userID string, limit, offset int) ([]model.ReportSummary, error) {
	return s.ReportRepo.ListByUser(ctx, userID, limit, offset)
}

func (s *ReportService) ListRecent(ctx context.Context, limit, offset int) ([]model.ReportSummary, error) {
	return s.ReportRepo.ListRecent(ctx, limit, offset)
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

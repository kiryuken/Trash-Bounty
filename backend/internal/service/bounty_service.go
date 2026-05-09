package service

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"net/http"
	"sort"
	"strings"
	"time"

	"trashbounty/internal/model"
	"trashbounty/internal/repository"
	"trashbounty/internal/service/ai"
)

type BountyService struct {
	BountyRepo      *repository.BountyRepo
	UserRepo        *repository.UserRepo
	NotifRepo       *repository.NotificationRepo
	TxRepo          *repository.TransactionRepo
	ReportRepo      *repository.ReportRepo
	AchievementRepo *repository.AchievementRepo
	CompletionAgent *ai.CompletionVerificationAgent
	RecommenderAgent *ai.RecommenderAgent
	AgentsInternalURL string
	AgentsInternalSecret string
	HTTPClient *http.Client
}

func NewBountyService(
	bountyRepo *repository.BountyRepo,
	userRepo *repository.UserRepo,
	notifRepo *repository.NotificationRepo,
	txRepo *repository.TransactionRepo,
	reportRepo *repository.ReportRepo,
	achievementRepo *repository.AchievementRepo,
	completionAgent *ai.CompletionVerificationAgent,
	recommenderAgent *ai.RecommenderAgent,
	agentsInternalURL string,
	agentsInternalSecret string,
) *BountyService {
	return &BountyService{
		BountyRepo:      bountyRepo,
		UserRepo:        userRepo,
		NotifRepo:       notifRepo,
		TxRepo:          txRepo,
		ReportRepo:      reportRepo,
		AchievementRepo: achievementRepo,
		CompletionAgent: completionAgent,
		RecommenderAgent: recommenderAgent,
		AgentsInternalURL: strings.TrimRight(agentsInternalURL, "/"),
		AgentsInternalSecret: agentsInternalSecret,
		HTTPClient: &http.Client{Timeout: 5 * time.Second},
	}
}

func (s *BountyService) ListOpen(ctx context.Context, limit, offset int) ([]model.BountySummary, error) {
	return s.BountyRepo.ListOpen(ctx, limit, offset)
}

func (s *BountyService) GetByID(ctx context.Context, id string) (*model.Bounty, error) {
	return s.BountyRepo.GetByID(ctx, id)
}

func (s *BountyService) Take(ctx context.Context, bountyID, executorID string) error {
	b, err := s.BountyRepo.GetByID(ctx, bountyID)
	if err != nil {
		return errors.New("bounty tidak ditemukan")
	}
	if b.Status != "open" {
		return errors.New("bounty sudah diambil")
	}
	if b.ReporterID == executorID {
		return errors.New("tidak bisa mengambil bounty sendiri")
	}

	taken, err := s.BountyRepo.Take(ctx, bountyID, executorID)
	if err != nil {
		return err
	}
	if !taken {
		return errors.New("bounty sudah diambil")
	}

	// Notify bounty creator
	_ = s.NotifRepo.Create(ctx, &model.Notification{
		UserID:  b.ReporterID,
		Type:    "info",
		Message: fmt.Sprintf("Bounty di \"%s\" telah diambil oleh seseorang.", b.LocationText),
	})
	s.sendTelegramNotificationAsync(b.ReporterID, fmt.Sprintf("Bounty di \"%s\" sudah diambil executor dan sedang dikerjakan.", b.LocationText))

	return nil
}

func (s *BountyService) Complete(ctx context.Context, bountyID, executorID, proofURL string) error {
	b, err := s.BountyRepo.GetByID(ctx, bountyID)
	if err != nil {
		return errors.New("bounty tidak ditemukan")
	}
	if b.ExecutorID == nil || *b.ExecutorID != executorID {
		return errors.New("anda bukan executor bounty ini")
	}
	if b.Status != "taken" && b.Status != "in_progress" {
		return errors.New("bounty tidak dalam status yang benar")
	}

	report, err := s.ReportRepo.GetByID(ctx, b.ReportID)
	if err != nil {
		return errors.New("laporan bounty tidak ditemukan")
	}

	if s.CompletionAgent != nil {
		verifyResult, err := s.CompletionAgent.Verify(report.ImageURL, proofURL, b.LocationText, b.WasteType)
		if err != nil {
			return fmt.Errorf("gagal memverifikasi bukti bounty: %w", err)
		}
		if !verifyResult.Approved {
			_ = s.BountyRepo.UpdateStatus(ctx, bountyID, "disputed")
			_ = s.NotifRepo.Create(ctx, &model.Notification{
				UserID:  executorID,
				Type:    "warning",
				Message: fmt.Sprintf("Bukti bounty di \"%s\" ditolak Lumi: %s", b.LocationText, verifyResult.Reasoning),
			})
			_ = s.NotifRepo.Create(ctx, &model.Notification{
				UserID:  b.ReporterID,
				Type:    "warning",
				Message: fmt.Sprintf("Bounty di \"%s\" masuk status disputed karena bukti pembersihan tidak meyakinkan.", b.LocationText),
			})
			s.sendTelegramNotificationAsync(executorID, fmt.Sprintf("Bukti bounty di \"%s\" ditolak Lumi. Status bounty sekarang disputed.", b.LocationText))
			s.sendTelegramNotificationAsync(b.ReporterID, fmt.Sprintf("Bounty di \"%s\" masuk status disputed karena bukti pembersihan tidak meyakinkan.", b.LocationText))
			return errors.New("bukti foto tidak membuktikan pembersihan")
		}
	}

	completed, err := s.BountyRepo.Complete(ctx, bountyID, executorID, proofURL)
	if err != nil {
		return err
	}
	if !completed {
		return errors.New("bounty tidak lagi dalam status yang benar")
	}

	// Update report status
	_ = s.ReportRepo.UpdateStatus(ctx, b.ReportID, "completed")

	// Reward executor (80% of reward)
	execPoints, execIDR, bonusPoints, bonusIDR := ai.SplitBountyReward(b.RewardPoints)
	_ = s.UserRepo.AddPoints(ctx, executorID, execPoints)
	_ = s.UserRepo.AddWallet(ctx, executorID, execIDR)

	desc := fmt.Sprintf("Reward bounty: %s", b.LocationText)
	_ = s.TxRepo.Create(ctx, &model.Transaction{
		UserID:      executorID,
		Type:        "points_earned_bounty",
		Status:      "completed",
		PointsDelta: &execPoints,
		IDRDelta:    &execIDR,
		ReferenceID: &bountyID,
		Description: &desc,
	})

	// Bonus to reporter (20%)
	_ = s.UserRepo.AddPoints(ctx, b.ReporterID, bonusPoints)
	_ = s.UserRepo.AddWallet(ctx, b.ReporterID, bonusIDR)

	bonusDesc := fmt.Sprintf("Bonus reporter bounty: %s", b.LocationText)
	_ = s.TxRepo.Create(ctx, &model.Transaction{
		UserID:      b.ReporterID,
		Type:        "points_bonus",
		Status:      "completed",
		PointsDelta: &bonusPoints,
		IDRDelta:    &bonusIDR,
		ReferenceID: &bountyID,
		Description: &bonusDesc,
	})

	// Notifications
	_ = s.NotifRepo.Create(ctx, &model.Notification{
		UserID:  executorID,
		Type:    "reward",
		Message: fmt.Sprintf("Bounty di \"%s\" selesai! Anda mendapat %d points.", b.LocationText, execPoints),
	})
	_ = s.NotifRepo.Create(ctx, &model.Notification{
		UserID:  b.ReporterID,
		Type:    "reward",
		Message: fmt.Sprintf("Bounty di \"%s\" telah diselesaikan. Anda mendapat bonus %d points!", b.LocationText, bonusPoints),
	})
	s.sendTelegramNotificationAsync(executorID, fmt.Sprintf("Bounty di \"%s\" selesai. Kamu mendapat %d points.", b.LocationText, execPoints))
	s.sendTelegramNotificationAsync(b.ReporterID, fmt.Sprintf("Bounty di \"%s\" selesai. Kamu mendapat bonus %d points.", b.LocationText, bonusPoints))

	// Check and award achievements
	s.checkBountyAchievements(ctx, executorID)
	s.checkPointsAchievements(ctx, executorID)
	s.checkPointsAchievements(ctx, b.ReporterID)

	return nil
}

func (s *BountyService) checkBountyAchievements(ctx context.Context, userID string) {
	count, err := s.BountyRepo.CountCompletedByUser(ctx, userID)
	if err != nil {
		return
	}
	thresholds := map[int]string{
		1: "first_bounty", 10: "bounties_10", 25: "bounties_25",
		50: "bounties_50",
	}
	for threshold, aType := range thresholds {
		if count >= threshold {
			_ = s.AchievementRepo.Grant(ctx, userID, aType)
		}
	}
}

func (s *BountyService) checkPointsAchievements(ctx context.Context, userID string) {
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

func (s *BountyService) ListByExecutor(ctx context.Context, userID string, limit, offset int) ([]model.BountySummary, error) {
	return s.BountyRepo.ListByExecutor(ctx, userID, limit, offset)
}

func (s *BountyService) ListByReporter(ctx context.Context, userID string, limit, offset int) ([]model.BountySummary, error) {
	return s.BountyRepo.ListByReporter(ctx, userID, limit, offset)
}

func (s *BountyService) Recommended(ctx context.Context, executorID string, lat, lon float64, limit int) ([]model.RecommendedBounty, error) {
	if limit <= 0 {
		limit = 5
	}

	pastWasteTypes, err := s.BountyRepo.GetCompletedWasteTypes(ctx, executorID)
	if err != nil {
		return nil, err
	}

	candidates, err := s.BountyRepo.ListOpenDetailed(ctx, 50, 0)
	if err != nil {
		return nil, err
	}

	inputs := make([]ai.RecommendationInput, 0, len(candidates))
	byID := make(map[string]model.RecommendedBounty, len(candidates))
	fallback := make([]model.RecommendedBounty, 0, len(candidates))

	for _, candidate := range candidates {
		distanceKM := ai.HaversineKM(lat, lon, candidate.Latitude, candidate.Longitude)
		estimatedTime := 0
		if candidate.EstimatedTimeMinutes != nil {
			estimatedTime = *candidate.EstimatedTimeMinutes
		}

		inputs = append(inputs, ai.RecommendationInput{
			ID:                   candidate.ID,
			WasteType:            candidate.WasteType,
			Severity:             candidate.Severity,
			RewardPoints:         candidate.RewardPoints,
			DistanceKM:           distanceKM,
			EstimatedTimeMinutes: estimatedTime,
		})

		distanceText := formatDistance(distanceKM)
		result := model.RecommendedBounty{
			BountySummary: model.BountySummary{
				ID:                   candidate.ID,
				LocationText:         candidate.LocationText,
				WasteType:            candidate.WasteType,
				Severity:             candidate.Severity,
				EstimatedTimeMinutes: candidate.EstimatedTimeMinutes,
				RewardPoints:         candidate.RewardPoints,
				RewardIDR:            candidate.RewardIDR,
				Status:               candidate.Status,
				ImageURL:             candidate.ImageURL,
				Distance:             &distanceText,
				CreatedAt:            candidate.CreatedAt.Format("2006-01-02T15:04:05Z"),
			},
			Reasoning: defaultReasoning(distanceKM, candidate.RewardPoints, estimatedTime),
			Score:     fallbackScore(distanceKM, candidate.RewardPoints, estimatedTime),
		}
		byID[candidate.ID] = result
		fallback = append(fallback, result)
	}

	sort.SliceStable(fallback, func(i, j int) bool {
		return fallback[i].Score > fallback[j].Score
	})

	if len(inputs) == 0 || s.RecommenderAgent == nil {
		return trimRecommendations(fallback, limit), nil
	}

	ranked, err := s.RecommenderAgent.Recommend(lat, lon, pastWasteTypes, inputs)
	if err != nil {
		return trimRecommendations(fallback, limit), nil
	}

	results := make([]model.RecommendedBounty, 0, len(fallback))
	used := make(map[string]struct{}, len(ranked))
	for _, recommendation := range ranked {
		candidate, ok := byID[recommendation.BountyID]
		if !ok {
			continue
		}
		candidate.Score = recommendation.Score
		candidate.Reasoning = recommendation.Reasoning
		results = append(results, candidate)
		used[recommendation.BountyID] = struct{}{}
	}
	for _, candidate := range fallback {
		if _, ok := used[candidate.ID]; ok {
			continue
		}
		results = append(results, candidate)
	}

	return trimRecommendations(results, limit), nil
}

func trimRecommendations(results []model.RecommendedBounty, limit int) []model.RecommendedBounty {
	if len(results) <= limit {
		return results
	}
	return results[:limit]
}

func formatDistance(distanceKM float64) string {
	if distanceKM < 1 {
		meters := int(math.Round(distanceKM * 1000))
		if meters < 1 {
			meters = 1
		}
		return fmt.Sprintf("%d m", meters)
	}
	return fmt.Sprintf("%.1f km", distanceKM)
}

func fallbackScore(distanceKM float64, rewardPoints, estimatedTime int) float64 {
	timeCost := float64(estimatedTime)
	if timeCost <= 0 {
		timeCost = 10
	}
	return float64(rewardPoints)/(timeCost+5) + 10/(distanceKM+1)
}

func defaultReasoning(distanceKM float64, rewardPoints, estimatedTime int) string {
	if estimatedTime <= 0 {
		return fmt.Sprintf("Dekat dari lokasi kamu dan punya reward %d poin.", rewardPoints)
	}
	return fmt.Sprintf("Jarak sekitar %s dengan estimasi %d menit dan reward %d poin.", formatDistance(distanceKM), estimatedTime, rewardPoints)
}

func (s *BountyService) sendTelegramNotificationAsync(userID, message string) {
	if s.AgentsInternalURL == "" || s.AgentsInternalSecret == "" || s.HTTPClient == nil {
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

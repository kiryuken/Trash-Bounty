package service

import (
	"context"
	"errors"

	"golang.org/x/crypto/bcrypt"

	"trashbounty/internal/model"
	"trashbounty/internal/repository"
)

type ProfileService struct {
	UserRepo        *repository.UserRepo
	AchievementRepo *repository.AchievementRepo
}

func NewProfileService(userRepo *repository.UserRepo, achievementRepo *repository.AchievementRepo) *ProfileService {
	return &ProfileService{UserRepo: userRepo, AchievementRepo: achievementRepo}
}

func (s *ProfileService) GetProfile(ctx context.Context, userID string) (*model.UserProfile, error) {
	profile, err := s.UserRepo.GetProfile(ctx, userID)
	if err != nil {
		return nil, err
	}

	// Attach achievements
	achievements, err := s.AchievementRepo.GetAchievementDTOs(ctx, userID)
	if err != nil {
		return nil, err
	}
	profile.Achievements = achievements

	return profile, nil
}

func (s *ProfileService) UpdateProfile(ctx context.Context, userID, name string, avatarURL *string) error {
	return s.UserRepo.UpdateProfile(ctx, userID, name, avatarURL)
}

func (s *ProfileService) GetPrivacy(ctx context.Context, userID string) (*model.PrivacySettings, error) {
	return s.UserRepo.GetPrivacy(ctx, userID)
}

func (s *ProfileService) UpdatePrivacy(ctx context.Context, userID string, isPublic, locationSharing, twoFactor bool) error {
	return s.UserRepo.UpdatePrivacy(ctx, userID, isPublic, locationSharing, twoFactor)
}

func (s *ProfileService) ChangePassword(ctx context.Context, userID, oldPassword, newPassword string) error {
	if len(newPassword) < 8 {
		return errors.New("password minimal 8 karakter")
	}

	user, err := s.UserRepo.GetByID(ctx, userID)
	if err != nil {
		return errors.New("user tidak ditemukan")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(oldPassword)); err != nil {
		return errors.New("password lama salah")
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(newPassword), 12)
	if err != nil {
		return err
	}

	return s.UserRepo.UpdatePassword(ctx, userID, string(hash))
}

func (s *ProfileService) GetHistory(ctx context.Context, userID string, limit, offset int) ([]model.HistoryItem, error) {
	return s.UserRepo.GetHistory(ctx, userID, limit, offset)
}

func (s *ProfileService) GetAchievements(ctx context.Context, userID string) ([]model.AchievementDTO, error) {
	return s.AchievementRepo.GetAchievementDTOs(ctx, userID)
}

type LeaderboardService struct {
	LeaderboardRepo *repository.LeaderboardRepo
}

func NewLeaderboardService(lbRepo *repository.LeaderboardRepo) *LeaderboardService {
	return &LeaderboardService{LeaderboardRepo: lbRepo}
}

func (s *LeaderboardService) GetLeaderboard(ctx context.Context, period string, limit int, role string, currentUserID string) (*model.LeaderboardResponse, error) {
	entries, err := s.LeaderboardRepo.GetLeaderboard(ctx, period, limit, role)
	if err != nil {
		return nil, err
	}

	resp := &model.LeaderboardResponse{
		Period:  period,
		Entries: entries,
	}

	// Mark current user and find their rank
	for i := range resp.Entries {
		if resp.Entries[i].ID == currentUserID {
			resp.Entries[i].IsCurrentUser = true
			entry := resp.Entries[i]
			resp.CurrentUserRank = &entry
		}
	}

	return resp, nil
}

func (s *LeaderboardService) RefreshViews() error {
	return s.LeaderboardRepo.RefreshViews()
}

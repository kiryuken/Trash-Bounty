package model

import (
	"time"
)

type User struct {
	ID               string  `json:"id"`
	Email            string  `json:"email"`
	PasswordHash     string  `json:"-"`
	Name             string  `json:"name"`
	AvatarURL        *string `json:"avatar_url"`
	Role             string  `json:"role"`
	Points           int            `json:"points"`
	WalletBalance    float64        `json:"wallet_balance"`
	Rank             *int           `json:"rank"`
	TelegramChatID   *string        `json:"telegram_chat_id,omitempty"`
	TelegramLinkToken *string       `json:"-"`
	TelegramLinkedAt *time.Time     `json:"telegram_linked_at,omitempty"`
	IsPublicProfile  bool           `json:"is_public_profile"`
	LocationSharing  bool           `json:"location_sharing"`
	TwoFactorEnabled bool           `json:"two_factor_enabled"`
	CreatedAt        time.Time      `json:"created_at"`
	UpdatedAt        time.Time      `json:"updated_at"`
}

type UserProfile struct {
	ID               string            `json:"id"`
	Name             string            `json:"name"`
	Email            string            `json:"email,omitempty"`
	AvatarURL        *string           `json:"avatar_url"`
	Role             string            `json:"role"`
	Points           int               `json:"points"`
	WalletBalance    float64           `json:"wallet_balance"`
	Rank             *int              `json:"rank"`
	TotalReports     int               `json:"total_reports"`
	TotalBounties    int               `json:"total_bounties"`
	SuccessRate      float64           `json:"success_rate"`
	JoinedAt         string            `json:"joined_at"`
	TelegramConnected bool             `json:"telegram_connected"`
	TelegramLinkedAt  *string          `json:"telegram_linked_at,omitempty"`
	IsPublicProfile  bool              `json:"is_public_profile"`
	LocationSharing  bool              `json:"location_sharing"`
	TwoFactorEnabled bool             `json:"two_factor_enabled"`
	Achievements     []AchievementDTO  `json:"achievements"`
}

type AchievementDTO struct {
	Type     string  `json:"type"`
	Icon     string  `json:"icon"`
	Name     string  `json:"name"`
	Unlocked bool    `json:"unlocked"`
	EarnedAt *string `json:"earned_at"`
}

type PrivacySettings struct {
	IsPublicProfile  bool `json:"public_profile"`
	LocationSharing  bool `json:"location_sharing"`
	TwoFactorEnabled bool `json:"two_factor_enabled"`
}

type HistoryItem struct {
	ID           string   `json:"id"`
	Type         string   `json:"type"`
	Status       string   `json:"status"`
	LocationText string   `json:"location"`
	Severity     int      `json:"severity"`
	RewardIDR    float64  `json:"reward"`
	PointsEarned *int     `json:"points_earned"`
	Date         string   `json:"date"`
	Duration     *string  `json:"duration"`
	CreatedAt    string   `json:"created_at"`
}

type RefreshToken struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	TokenHash string    `json:"-"`
	ExpiresAt time.Time `json:"expires_at"`
	CreatedAt time.Time `json:"created_at"`
}

package model

type AIResult struct {
	WasteType    string  `json:"waste_type"`
	Severity     int     `json:"severity"`
	Confidence   float64 `json:"confidence"`
	Reasoning    string  `json:"reasoning"`
	Approved     bool    `json:"approved"`
	RewardPoints int     `json:"reward_points"`
	RewardIDR    float64 `json:"reward_idr"`
}

type LeaderboardEntry struct {
	ID            string  `json:"id"`
	Name          string  `json:"name"`
	AvatarURL     *string `json:"avatar"`
	Role          string  `json:"role"`
	Points        int     `json:"points"`
	Tasks         int     `json:"tasks"`
	Rank          int     `json:"rank"`
	Badge         string  `json:"badge"`
	IsCurrentUser bool    `json:"is_current_user"`
}

type LeaderboardResponse struct {
	Period          string            `json:"period"`
	Entries         []LeaderboardEntry `json:"entries"`
	CurrentUserRank *LeaderboardEntry  `json:"current_user_rank"`
}

type HomeStats struct {
	TotalReports    int     `json:"total_reports"`
	TotalPoints     int     `json:"total_points"`
	CurrentRank     *int    `json:"current_rank"`
	WalletBalance   float64 `json:"wallet_balance"`
	PendingBounties int     `json:"pending_bounties"`
}

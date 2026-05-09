package model

type CleanupStats struct {
	Period             string          `json:"period"`
	TotalCompleted     int             `json:"total_completed"`
	TotalPointsAwarded int             `json:"total_points_awarded"`
	TotalRewardIDR     float64         `json:"total_reward_idr"`
	TotalWeightKG      float64         `json:"total_weight_kg"`
	WasteTypes         []WasteTypeStat `json:"waste_types"`
}

type WasteTypeStat struct {
	WasteType   string  `json:"waste_type"`
	Count       int     `json:"count"`
	AvgSeverity float64 `json:"avg_severity"`
}

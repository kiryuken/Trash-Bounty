package model

import (
	"encoding/json"
	"time"
)

type Report struct {
	ID                string           `json:"id"`
	ReporterID        string           `json:"reporter_id"`
	ImageURL          string           `json:"image_url"`
	LocationText      string           `json:"location_text"`
	Latitude          float64          `json:"latitude"`
	Longitude         float64          `json:"longitude"`
	Status            string           `json:"status"`
	WasteType         *string          `json:"waste_type"`
	Severity          *int             `json:"severity"`
	EstimatedWeightKG *float64         `json:"estimated_weight_kg"`
	AiConfidence      *float64         `json:"ai_confidence"`
	AiReasoning       *string          `json:"ai_reasoning"`
	MiniRawResult     *json.RawMessage `json:"mini_raw_result,omitempty"`
	StandardRawResult *json.RawMessage `json:"standard_raw_result,omitempty"`
	PointsEarned      *int             `json:"points_earned"`
	RewardIDR         *float64         `json:"reward_idr"`
	CreatedAt         time.Time        `json:"created_at"`
	UpdatedAt         time.Time        `json:"updated_at"`
}

type ReportSummary struct {
	ID           string  `json:"id"`
	LocationText string  `json:"location_text"`
	Status       string  `json:"status"`
	WasteType    *string `json:"waste_type"`
	Severity     *int    `json:"severity"`
	Points       *int    `json:"points_earned"`
	ImageURL     string  `json:"image_url"`
	CreatedAt    string  `json:"created_at"`
}

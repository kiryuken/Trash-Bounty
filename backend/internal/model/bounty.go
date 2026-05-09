package model

import (
	"time"
)

type Bounty struct {
	ID                   string     `json:"id"`
	ReportID             string     `json:"report_id"`
	ReporterID           string     `json:"reporter_id"`
	ExecutorID           *string    `json:"executor_id"`
	LocationText         string     `json:"location"`
	Address              *string    `json:"address"`
	WasteType            string     `json:"waste_type"`
	Severity             int        `json:"severity"`
	EstimatedTimeMinutes *int       `json:"estimated_time"`
	RewardPoints         int        `json:"reward_points"`
	RewardIDR            float64    `json:"reward"`
	Latitude             float64    `json:"latitude"`
	Longitude            float64    `json:"longitude"`
	ImageURL             string     `json:"image"`
	Status               string     `json:"status"`
	ProofImageURL        *string    `json:"proof_image_url"`
	TakenAt              *time.Time `json:"taken_at"`
	CompletedAt          *time.Time `json:"completed_at"`
	CreatedAt            time.Time  `json:"created_at"`
	UpdatedAt            time.Time  `json:"updated_at"`
}

type BountySummary struct {
	ID                   string  `json:"id"`
	LocationText         string  `json:"location"`
	WasteType            string  `json:"waste_type"`
	Severity             int     `json:"severity"`
	EstimatedTimeMinutes *int    `json:"estimated_time"`
	RewardPoints         int     `json:"reward_points"`
	RewardIDR            float64 `json:"reward"`
	Status               string  `json:"status"`
	ImageURL             string  `json:"image"`
	Distance             *string `json:"distance,omitempty"`
	CreatedAt            string  `json:"created_at"`
}

type RecommendedBounty struct {
	BountySummary
	Score     float64 `json:"score"`
	Reasoning string  `json:"reasoning"`
}

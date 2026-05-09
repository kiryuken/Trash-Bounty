package model

import "time"

type Notification struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Type      string    `json:"type"`
	Message   string    `json:"message"`
	IsRead    bool      `json:"is_read"`
	CreatedAt time.Time `json:"created_at"`
}

type Transaction struct {
	ID          string     `json:"id"`
	UserID      string     `json:"user_id"`
	Type        string     `json:"type"`
	Status      string     `json:"status"`
	PointsDelta *int       `json:"points_delta"`
	IDRDelta    *float64   `json:"idr_delta"`
	ReferenceID *string    `json:"reference_id"`
	Description *string    `json:"description"`
	QRCodeURL   *string    `json:"qr_code_url"`
	QRExpiresAt *time.Time `json:"qr_expires_at"`
	CreatedAt   time.Time  `json:"created_at"`
	CompletedAt *time.Time `json:"completed_at"`
}

type Achievement struct {
	ID       string    `json:"id"`
	UserID   string    `json:"user_id"`
	Type     string    `json:"type"`
	EarnedAt time.Time `json:"earned_at"`
}

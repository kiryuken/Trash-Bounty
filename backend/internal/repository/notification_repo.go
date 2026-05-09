package repository

import (
	"context"
	"database/sql"

	"trashbounty/internal/model"
)

type NotificationRepo struct {
	DB *sql.DB
}

func NewNotificationRepo(db *sql.DB) *NotificationRepo {
	return &NotificationRepo{DB: db}
}

func (r *NotificationRepo) Create(ctx context.Context, n *model.Notification) error {
	return r.DB.QueryRowContext(ctx, `
		INSERT INTO notifications (user_id, type, message)
		VALUES ($1, $2, $3)
		RETURNING id, created_at`,
		n.UserID, n.Type, n.Message,
	).Scan(&n.ID, &n.CreatedAt)
}

func (r *NotificationRepo) ListByUser(ctx context.Context, userID string, limit, offset int) ([]model.Notification, error) {
	rows, err := r.DB.QueryContext(ctx, `
		SELECT id, user_id, type, message, is_read, created_at
		FROM notifications WHERE user_id = $1
		ORDER BY created_at DESC LIMIT $2 OFFSET $3`, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []model.Notification
	for rows.Next() {
		var n model.Notification
		if err := rows.Scan(&n.ID, &n.UserID, &n.Type, &n.Message,
			&n.IsRead, &n.CreatedAt); err != nil {
			return nil, err
		}
		results = append(results, n)
	}
	return results, rows.Err()
}

func (r *NotificationRepo) MarkRead(ctx context.Context, id, userID string) error {
	_, err := r.DB.ExecContext(ctx, `UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2`, id, userID)
	return err
}

func (r *NotificationRepo) MarkAllRead(ctx context.Context, userID string) error {
	_, err := r.DB.ExecContext(ctx, `UPDATE notifications SET is_read = true WHERE user_id = $1 AND is_read = false`, userID)
	return err
}

func (r *NotificationRepo) UnreadCount(ctx context.Context, userID string) (int, error) {
	var count int
	err := r.DB.QueryRowContext(ctx, `SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = false`, userID).Scan(&count)
	return count, err
}

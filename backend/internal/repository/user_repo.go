package repository

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"time"

	"trashbounty/internal/model"
)

type UserRepo struct {
	DB *sql.DB
}

func NewUserRepo(db *sql.DB) *UserRepo {
	return &UserRepo{DB: db}
}

func (r *UserRepo) Create(ctx context.Context, u *model.User) error {
	return r.DB.QueryRowContext(ctx, `
		INSERT INTO users (email, password_hash, name, role)
		VALUES ($1, $2, $3, $4)
		RETURNING id, created_at, updated_at`,
		u.Email, u.PasswordHash, u.Name, u.Role,
	).Scan(&u.ID, &u.CreatedAt, &u.UpdatedAt)
}

func (r *UserRepo) GetByEmail(ctx context.Context, email string) (*model.User, error) {
	u := &model.User{}
	err := r.DB.QueryRowContext(ctx, `
		SELECT id, email, password_hash, name, avatar_url, role, points, wallet_balance,
		       rank, is_public_profile, location_sharing, two_factor_enabled, created_at, updated_at
		FROM users WHERE email = $1`, email,
	).Scan(&u.ID, &u.Email, &u.PasswordHash, &u.Name, &u.AvatarURL, &u.Role,
		&u.Points, &u.WalletBalance, &u.Rank, &u.IsPublicProfile, &u.LocationSharing,
		&u.TwoFactorEnabled, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return u, nil
}

func (r *UserRepo) GetByID(ctx context.Context, id string) (*model.User, error) {
	u := &model.User{}
	err := r.DB.QueryRowContext(ctx, `
		SELECT id, email, password_hash, name, avatar_url, role, points, wallet_balance,
		       rank, is_public_profile, location_sharing, two_factor_enabled, created_at, updated_at
		FROM users WHERE id = $1`, id,
	).Scan(&u.ID, &u.Email, &u.PasswordHash, &u.Name, &u.AvatarURL, &u.Role,
		&u.Points, &u.WalletBalance, &u.Rank, &u.IsPublicProfile, &u.LocationSharing,
		&u.TwoFactorEnabled, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return u, nil
}

func (r *UserRepo) UpdateProfile(ctx context.Context, id, name string, avatarURL *string) error {
	if avatarURL != nil {
		_, err := r.DB.ExecContext(ctx, `UPDATE users SET name=$1, avatar_url=$2, updated_at=NOW() WHERE id=$3`,
			name, *avatarURL, id)
		return err
	}
	_, err := r.DB.ExecContext(ctx, `UPDATE users SET name=$1, updated_at=NOW() WHERE id=$2`, name, id)
	return err
}

func (r *UserRepo) UpdatePrivacy(ctx context.Context, id string, isPublic, locationSharing, twoFactor bool) error {
	_, err := r.DB.ExecContext(ctx, `UPDATE users SET is_public_profile=$1, location_sharing=$2, two_factor_enabled=$3, updated_at=NOW() WHERE id=$4`,
		isPublic, locationSharing, twoFactor, id)
	return err
}

func (r *UserRepo) AddPoints(ctx context.Context, id string, points int) error {
	_, err := r.DB.ExecContext(ctx, `UPDATE users SET points = points + $1, updated_at=NOW() WHERE id = $2`, points, id)
	return err
}

func (r *UserRepo) AddWallet(ctx context.Context, id string, amount float64) error {
	_, err := r.DB.ExecContext(ctx, `UPDATE users SET wallet_balance = wallet_balance + $1, updated_at=NOW() WHERE id = $2`, amount, id)
	return err
}

func (r *UserRepo) GetProfile(ctx context.Context, id string) (*model.UserProfile, error) {
	p := &model.UserProfile{}
	var avatarURL sql.NullString
	var rank sql.NullInt32
	var telegramLinkedAt sql.NullString
	err := r.DB.QueryRowContext(ctx, `
		SELECT u.id, u.name, u.email, u.avatar_url, u.role, u.points, u.wallet_balance,
		       u.rank, u.is_public_profile, u.location_sharing, u.two_factor_enabled,
		       COALESCE(u.telegram_chat_id, '') <> '' AS telegram_connected,
		       to_char(u.telegram_linked_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS telegram_linked_at,
		       to_char(u.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS joined_at,
		       (SELECT COUNT(*) FROM reports WHERE reporter_id = u.id) AS total_reports,
		       (SELECT COUNT(*) FROM bounties WHERE executor_id = u.id AND status = 'completed') AS total_bounties
		FROM users u WHERE u.id = $1`, id,
	).Scan(&p.ID, &p.Name, &p.Email, &avatarURL, &p.Role, &p.Points, &p.WalletBalance,
		&rank, &p.IsPublicProfile, &p.LocationSharing, &p.TwoFactorEnabled,
		&p.TelegramConnected, &telegramLinkedAt,
		&p.JoinedAt, &p.TotalReports, &p.TotalBounties)
	if err != nil {
		return nil, err
	}
	if avatarURL.Valid {
		p.AvatarURL = &avatarURL.String
	}
	if rank.Valid {
		v := int(rank.Int32)
		p.Rank = &v
	}
	if telegramLinkedAt.Valid {
		p.TelegramLinkedAt = &telegramLinkedAt.String
	}
	// Calculate success rate: approved reports / total reports
	if p.TotalReports > 0 {
		var approved int
		_ = r.DB.QueryRowContext(ctx, `SELECT COUNT(*) FROM reports WHERE reporter_id = $1 AND status IN ('approved','bounty_created','completed')`, id).Scan(&approved)
		p.SuccessRate = float64(approved) / float64(p.TotalReports)
	}
	return p, nil
}

// Refresh tokens

func hashToken(token string) string {
	h := sha256.Sum256([]byte(token))
	return hex.EncodeToString(h[:])
}

func (r *UserRepo) SaveRefreshToken(ctx context.Context, userID, token string, expiresAt time.Time) error {
	_, err := r.DB.ExecContext(ctx, `
		INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
		VALUES ($1, $2, $3)`, userID, hashToken(token), expiresAt)
	return err
}

func (r *UserRepo) GetRefreshToken(ctx context.Context, token string) (*model.RefreshToken, error) {
	rt := &model.RefreshToken{}
	err := r.DB.QueryRowContext(ctx, `
		SELECT id, user_id, token_hash, expires_at, created_at
		FROM refresh_tokens WHERE token_hash = $1`, hashToken(token),
	).Scan(&rt.ID, &rt.UserID, &rt.TokenHash, &rt.ExpiresAt, &rt.CreatedAt)
	if err != nil {
		return nil, err
	}
	return rt, nil
}

func (r *UserRepo) DeleteRefreshToken(ctx context.Context, token string) error {
	_, err := r.DB.ExecContext(ctx, `DELETE FROM refresh_tokens WHERE token_hash = $1`, hashToken(token))
	return err
}

func (r *UserRepo) DeleteRefreshTokensByUser(ctx context.Context, userID string) error {
	_, err := r.DB.ExecContext(ctx, `DELETE FROM refresh_tokens WHERE user_id = $1`, userID)
	return err
}

func (r *UserRepo) GetPrivacy(ctx context.Context, id string) (*model.PrivacySettings, error) {
	p := &model.PrivacySettings{}
	err := r.DB.QueryRowContext(ctx, `
		SELECT is_public_profile, location_sharing, two_factor_enabled
		FROM users WHERE id = $1`, id,
	).Scan(&p.IsPublicProfile, &p.LocationSharing, &p.TwoFactorEnabled)
	if err != nil {
		return nil, err
	}
	return p, nil
}

func (r *UserRepo) UpdatePassword(ctx context.Context, id, passwordHash string) error {
	_, err := r.DB.ExecContext(ctx, `UPDATE users SET password_hash=$1, updated_at=NOW() WHERE id=$2`, passwordHash, id)
	return err
}

func (r *UserRepo) UpdateTelegramLinkToken(ctx context.Context, userID, token string) error {
	_, err := r.DB.ExecContext(ctx, `
		UPDATE users SET telegram_link_token=$1, updated_at=NOW()
		WHERE id=$2`, token, userID)
	return err
}

func (r *UserRepo) GetByTelegramLinkToken(ctx context.Context, token string) (*model.User, error) {
	u := &model.User{}
	err := r.DB.QueryRowContext(ctx, `
		SELECT id, email, name, role, telegram_chat_id, telegram_link_token, telegram_linked_at, created_at, updated_at
		FROM users WHERE telegram_link_token = $1`, token,
	).Scan(&u.ID, &u.Email, &u.Name, &u.Role, &u.TelegramChatID, &u.TelegramLinkToken, &u.TelegramLinkedAt, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return u, nil
}

func (r *UserRepo) LinkTelegramChat(ctx context.Context, userID, chatID string) error {
	_, err := r.DB.ExecContext(ctx, `
		UPDATE users
		SET telegram_chat_id=$1, telegram_link_token=NULL, telegram_linked_at=NOW(), updated_at=NOW()
		WHERE id=$2`, chatID, userID)
	return err
}

func (r *UserRepo) UnlinkTelegramChat(ctx context.Context, userID string) error {
	_, err := r.DB.ExecContext(ctx, `
		UPDATE users
		SET telegram_chat_id=NULL, telegram_link_token=NULL, telegram_linked_at=NULL, updated_at=NOW()
		WHERE id=$1`, userID)
	return err
}

func (r *UserRepo) GetByTelegramChatID(ctx context.Context, chatID string) (*model.User, error) {
	u := &model.User{}
	err := r.DB.QueryRowContext(ctx, `
		SELECT id, email, name, role, telegram_chat_id, telegram_linked_at, created_at, updated_at
		FROM users WHERE telegram_chat_id = $1`, chatID,
	).Scan(&u.ID, &u.Email, &u.Name, &u.Role, &u.TelegramChatID, &u.TelegramLinkedAt, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return u, nil
}

func (r *UserRepo) GetTelegramChatID(ctx context.Context, userID string) (*string, error) {
	var chatID sql.NullString
	err := r.DB.QueryRowContext(ctx, `SELECT telegram_chat_id FROM users WHERE id = $1`, userID).Scan(&chatID)
	if err != nil {
		return nil, err
	}
	if !chatID.Valid || chatID.String == "" {
		return nil, nil
	}
	return &chatID.String, nil
}

func (r *UserRepo) GetHistory(ctx context.Context, id string, limit, offset int) ([]model.HistoryItem, error) {
	rows, err := r.DB.QueryContext(ctx, `
		SELECT * FROM (
			SELECT r.id, 'report' AS type, r.status::text,
			       r.location_text AS location, COALESCE(r.severity, 0) AS severity,
			       COALESCE(r.reward_idr, 0) AS reward,
			       r.points_earned,
			       to_char(r.created_at, 'DD Mon YYYY') AS date,
			       NULL::text AS duration,
			       to_char(r.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
			FROM reports r WHERE r.reporter_id = $1
			UNION ALL
			SELECT b.id, 'bounty' AS type, b.status::text,
			       b.location_text AS location, b.severity,
			       CASE WHEN b.status = 'completed' THEN b.reward_idr * 0.8 ELSE b.reward_idr END AS reward,
			       CASE WHEN b.status = 'completed' THEN (b.reward_points * 80) / 100 ELSE NULL END AS points_earned,
			       to_char(b.created_at, 'DD Mon YYYY') AS date,
			       CASE WHEN b.completed_at IS NOT NULL AND b.taken_at IS NOT NULL
			            THEN CAST(EXTRACT(EPOCH FROM (b.completed_at - b.taken_at)) / 60 AS INTEGER) || ' menit'
			            ELSE NULL END AS duration,
			       to_char(b.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
			FROM bounties b WHERE b.executor_id = $1
		) combined
		ORDER BY created_at DESC LIMIT $2 OFFSET $3`, id, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []model.HistoryItem
	for rows.Next() {
		var h model.HistoryItem
		if err := rows.Scan(&h.ID, &h.Type, &h.Status, &h.LocationText,
			&h.Severity, &h.RewardIDR, &h.PointsEarned, &h.Date,
			&h.Duration, &h.CreatedAt); err != nil {
			return nil, err
		}
		results = append(results, h)
	}
	return results, rows.Err()
}

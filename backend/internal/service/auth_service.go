package service

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"golang.org/x/crypto/bcrypt"

	"trashbounty/internal/model"
	"trashbounty/internal/repository"
	jwtpkg "trashbounty/pkg/jwt"
)

type AuthService struct {
	UserRepo  *repository.UserRepo
	JWTSecret string
}

func NewAuthService(userRepo *repository.UserRepo, jwtSecret string) *AuthService {
	return &AuthService{UserRepo: userRepo, JWTSecret: jwtSecret}
}

type UserDTO struct {
	ID            string  `json:"id"`
	Name          string  `json:"name"`
	Email         string  `json:"email"`
	Role          string  `json:"role"`
	AvatarURL     *string `json:"avatar_url"`
	Points        int     `json:"points"`
	WalletBalance float64 `json:"wallet_balance"`
	Rank          *int    `json:"rank"`
}

type AuthResponse struct {
	Token        string  `json:"token"`
	RefreshToken string  `json:"refresh_token"`
	User         UserDTO `json:"user"`
}

type RegisterInput struct {
	Email    string `json:"email"`
	Password string `json:"password"`
	Name     string `json:"name"`
	Role     string `json:"role"`
}

type LoginInput struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func authRoleLabel(role string) string {
	switch role {
	case "executor":
		return "eksekutor"
	case "reporter":
		return "pelapor"
	default:
		return role
	}
}

func (s *AuthService) Register(ctx context.Context, input RegisterInput) (*AuthResponse, error) {
	if input.Email == "" || input.Password == "" || input.Name == "" {
		return nil, errors.New("email, password, dan nama wajib diisi")
	}
	if len(input.Password) < 8 {
		return nil, errors.New("password minimal 8 karakter")
	}

	existing, _ := s.UserRepo.GetByEmail(ctx, input.Email)
	if existing != nil {
		return nil, errors.New("email sudah terdaftar sebagai " + authRoleLabel(existing.Role) + ", silakan login atau gunakan email berbeda")
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(input.Password), 12)
	if err != nil {
		return nil, err
	}

	role := input.Role
	if role == "" {
		role = "reporter"
	}
	if role != "reporter" && role != "executor" {
		return nil, errors.New("role harus reporter atau executor")
	}

	user := &model.User{
		Email:        input.Email,
		PasswordHash: string(hash),
		Name:         input.Name,
		Role:         role,
	}

	if err := s.UserRepo.Create(ctx, user); err != nil {
		return nil, err
	}

	resp, err := s.generateAuthResponse(ctx, user)
	if err != nil {
		return nil, err
	}

	return resp, nil
}

func (s *AuthService) Login(ctx context.Context, input LoginInput) (*AuthResponse, error) {
	if input.Email == "" || input.Password == "" {
		return nil, errors.New("email dan password wajib diisi")
	}

	user, err := s.UserRepo.GetByEmail(ctx, input.Email)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, errors.New("email atau password salah")
		}
		return nil, err
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(input.Password)); err != nil {
		return nil, errors.New("email atau password salah")
	}

	resp, err := s.generateAuthResponse(ctx, user)
	if err != nil {
		return nil, err
	}

	return resp, nil
}

func (s *AuthService) RefreshToken(ctx context.Context, refreshToken string) (*AuthResponse, error) {
	rt, err := s.UserRepo.GetRefreshToken(ctx, refreshToken)
	if err != nil {
		return nil, errors.New("refresh token tidak valid")
	}

	if time.Now().After(rt.ExpiresAt) {
		_ = s.UserRepo.DeleteRefreshToken(ctx, refreshToken)
		return nil, errors.New("refresh token expired")
	}

	user, err := s.UserRepo.GetByID(ctx, rt.UserID)
	if err != nil {
		return nil, err
	}

	_ = s.UserRepo.DeleteRefreshToken(ctx, refreshToken)

	resp, err := s.generateAuthResponse(ctx, user)
	if err != nil {
		return nil, err
	}

	return resp, nil
}

func (s *AuthService) Logout(ctx context.Context, refreshToken string) error {
	return s.UserRepo.DeleteRefreshToken(ctx, refreshToken)
}

func (s *AuthService) generateAuthResponse(ctx context.Context, user *model.User) (*AuthResponse, error) {
	accessToken, err := jwtpkg.Sign(user.ID, user.Role, s.JWTSecret)
	if err != nil {
		return nil, err
	}

	refreshToken, err := jwtpkg.GenerateRefreshToken()
	if err != nil {
		return nil, err
	}

	expiresAt := time.Now().Add(7 * 24 * time.Hour)
	if err := s.UserRepo.SaveRefreshToken(ctx, user.ID, refreshToken, expiresAt); err != nil {
		return nil, err
	}

	return &AuthResponse{
		Token:        accessToken,
		RefreshToken: refreshToken,
		User: UserDTO{
			ID:            user.ID,
			Name:          user.Name,
			Email:         user.Email,
			Role:          user.Role,
			AvatarURL:     user.AvatarURL,
			Points:        user.Points,
			WalletBalance: user.WalletBalance,
			Rank:          user.Rank,
		},
	}, nil
}

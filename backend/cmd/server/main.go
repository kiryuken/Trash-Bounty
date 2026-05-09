package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"trashbounty/internal/config"
	"trashbounty/internal/db"
	"trashbounty/internal/handler"
	"trashbounty/internal/middleware"
	"trashbounty/internal/repository"
	"trashbounty/internal/service"
	"trashbounty/internal/service/ai"
)

func main() {
	cfg := config.Load()

	database, err := db.Connect(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Database connection failed: %v", err)
	}
	defer database.Close()
	log.Println("Database connected successfully")

	// Repositories
	userRepo := repository.NewUserRepo(database)
	reportRepo := repository.NewReportRepo(database)
	bountyRepo := repository.NewBountyRepo(database)
	notifRepo := repository.NewNotificationRepo(database)
	txRepo := repository.NewTransactionRepo(database)
	lbRepo := repository.NewLeaderboardRepo(database)
	statsRepo := repository.NewStatsRepo(database)
	achievementRepo := repository.NewAchievementRepo(database)

	// AI pipeline
	openaiClient := ai.NewOpenAIClient(cfg.OpenAIAPIKey)
	wasteAgent := ai.NewWasteAgent(openaiClient, cfg.GPTMiniModel)
	validationAgent := ai.NewValidationAgent(openaiClient, cfg.GPTStandardModel)
	completionAgent := ai.NewCompletionVerificationAgent(openaiClient, cfg.GPTStandardModel)
	recommenderAgent := ai.NewRecommenderAgent(openaiClient, cfg.GPTMiniModel)
	supportAgent := ai.NewSupportAgent(openaiClient, cfg.GPTChatModel)
	orchestrator := ai.NewOrchestrator(wasteAgent, validationAgent)

	// Services
	authSvc := service.NewAuthService(userRepo, cfg.JWTSecret)
	reportSvc := service.NewReportService(reportRepo, bountyRepo, userRepo, notifRepo, txRepo, achievementRepo, orchestrator, cfg.AgentsInternalURL, cfg.AgentsInternalSecret)
	bountySvc := service.NewBountyService(bountyRepo, userRepo, notifRepo, txRepo, reportRepo, achievementRepo, completionAgent, recommenderAgent, cfg.AgentsInternalURL, cfg.AgentsInternalSecret)
	profileSvc := service.NewProfileService(userRepo, achievementRepo)
	lbSvc := service.NewLeaderboardService(lbRepo)

	// Refresh materialized views on startup
	if err := lbRepo.RefreshViews(); err != nil {
		log.Printf("Warning: could not refresh leaderboard views: %v", err)
	}

	// Handlers
	authH := handler.NewAuthHandler(authSvc)
	reportH := handler.NewReportHandler(reportSvc)
	bountyH := handler.NewBountyHandler(bountySvc)
	profileH := handler.NewProfileHandler(profileSvc)
	lbH := handler.NewLeaderboardHandler(lbSvc)
	notifH := handler.NewNotificationHandler(notifRepo)
	homeH := handler.NewHomeHandler(statsRepo, reportRepo, bountyRepo)
	statsH := handler.NewStatsHandler(statsRepo, cfg.AgentsInternalURL, cfg.AgentsInternalSecret)
	txH := handler.NewTransactionHandler(txRepo)
	supportH := handler.NewSupportHandler(supportAgent)
	telegramH := handler.NewTelegramHandler(userRepo)
	telegramInternalH := handler.NewTelegramInternalHandler(userRepo, statsRepo, bountySvc, reportSvc, reportRepo, supportAgent, cfg.AgentsInternalSecret)

	// Router using net/http ServeMux (Go 1.22+)
	mux := http.NewServeMux()
	authMw := middleware.Auth(cfg.JWTSecret)

	// Helper to wrap handler with auth middleware
	protected := func(fn http.HandlerFunc) http.Handler {
		return authMw(fn)
	}

	// Health check
	mux.HandleFunc("GET /v1/health", handler.HealthCheck)

	// Auth (public)
	mux.HandleFunc("POST /v1/auth/register", authH.Register)
	mux.HandleFunc("POST /v1/auth/login", authH.Login)
	mux.HandleFunc("POST /v1/auth/refresh", authH.RefreshToken)
	mux.HandleFunc("POST /v1/auth/logout", authH.Logout)

	// Public endpoints
	mux.HandleFunc("GET /v1/reports/recent", reportH.ListRecent)
	mux.HandleFunc("GET /v1/bounties", bountyH.ListOpen)
	mux.HandleFunc("GET /v1/stats/cleanup", statsH.GetCleanupStats)
	mux.HandleFunc("POST /v1/telegram/link", telegramH.Link)
	mux.HandleFunc("DELETE /internal/telegram/{chatID}/link", telegramInternalH.Unlink)
	mux.HandleFunc("GET /internal/telegram/{chatID}/status", telegramInternalH.Status)
	mux.HandleFunc("GET /internal/telegram/{chatID}/bounties", telegramInternalH.Bounties)
	mux.HandleFunc("GET /internal/telegram/{chatID}/recommended", telegramInternalH.Recommended)
	mux.HandleFunc("POST /internal/telegram/{chatID}/report", telegramInternalH.CreateReport)
	mux.HandleFunc("GET /internal/telegram/{chatID}/reports", telegramInternalH.ListReports)
	mux.HandleFunc("GET /internal/telegram/{chatID}/reports/{reportID}", telegramInternalH.ReportStatus)
	mux.HandleFunc("POST /internal/telegram/support", telegramInternalH.Support)

	// Protected: Leaderboard
	mux.Handle("GET /v1/leaderboard", protected(lbH.Get))

	// Protected: Home dashboard (per-user stats)
	mux.Handle("GET /v1/home/stats", protected(homeH.Dashboard))
	mux.Handle("POST /v1/stats/report/download", protected(statsH.GenerateReport))

	// Protected: Reports
	mux.Handle("POST /v1/reports", protected(reportH.Create))
	mux.Handle("GET /v1/reports/mine", protected(reportH.ListMine))
	mux.Handle("GET /v1/reports/{id}", protected(reportH.GetByID))
	mux.Handle("GET /v1/reports/{id}/status", protected(reportH.GetStatus))

	// Protected: Bounties
	mux.Handle("GET /v1/bounties/recommended", protected(bountyH.RecommendedBounties))
	mux.Handle("GET /v1/bounties/{id}", protected(bountyH.GetByID))
	mux.Handle("POST /v1/bounties/{id}/take", protected(bountyH.Take))
	mux.Handle("POST /v1/bounties/{id}/complete", protected(bountyH.Complete))
	mux.Handle("GET /v1/bounties/mine", protected(bountyH.ListMyBounties))

	// Protected: Profile
	mux.Handle("GET /v1/users/me", protected(profileH.GetProfile))
	mux.Handle("PUT /v1/users/me", protected(profileH.UpdateProfile))
	mux.Handle("GET /v1/users/me/achievements", protected(profileH.GetAchievements))
	mux.Handle("GET /v1/users/me/history", protected(profileH.GetHistory))
	mux.Handle("GET /v1/users/me/privacy", protected(profileH.GetPrivacy))
	mux.Handle("PUT /v1/users/me/privacy", protected(profileH.UpdatePrivacy))
	mux.Handle("POST /v1/users/me/change-password", protected(profileH.ChangePassword))
	mux.Handle("GET /v1/telegram/token", protected(telegramH.GenerateToken))
	mux.Handle("DELETE /v1/telegram/link", protected(telegramH.Unlink))

	// Protected: Notifications
	mux.Handle("GET /v1/notifications", protected(notifH.List))
	mux.Handle("PUT /v1/notifications/{id}/read", protected(notifH.MarkRead))
	mux.Handle("PUT /v1/notifications/read-all", protected(notifH.MarkAllRead))
	mux.Handle("GET /v1/notifications/unread-count", protected(notifH.UnreadCount))
	mux.Handle("POST /v1/support/chat", protected(supportH.Chat))

	// Protected: Transactions
	mux.Handle("GET /v1/users/me/transactions", protected(txH.List))

	// Static file serving for uploads
	if err := os.MkdirAll("./uploads/reports", 0755); err != nil {
		log.Printf("Warning: could not create uploads dir: %v", err)
	}
	mux.Handle("/uploads/", http.StripPrefix("/uploads/", http.FileServer(http.Dir("./uploads"))))

	// Apply global middleware
	var h http.Handler = mux
	h = middleware.RateLimit(100)(h)
	h = middleware.CORS(cfg.AllowedOrigins)(h)
	h = middleware.Logger(h)
	h = middleware.Recovery(h)

	addr := ":" + cfg.Port
	server := &http.Server{
		Addr:    addr,
		Handler: h,
	}
	defer middleware.ShutdownRateLimiter()

	shutdownSignal, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	serverErrCh := make(chan error, 1)
	go func() {
		log.Printf("Server starting on %s (env: %s)", addr, cfg.AppEnv)
		serverErrCh <- server.ListenAndServe()
	}()

	select {
	case err := <-serverErrCh:
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("Server failed: %v", err)
		}
	case <-shutdownSignal.Done():
		log.Println("Shutdown signal received, stopping server gracefully")

		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		if err := server.Shutdown(shutdownCtx); err != nil {
			log.Printf("Graceful shutdown failed: %v", err)
			if closeErr := server.Close(); closeErr != nil {
				log.Printf("Forced server close failed: %v", closeErr)
			}
		}

		if err := <-serverErrCh; err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("Server failed during shutdown: %v", err)
		}
	}
}

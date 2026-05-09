package handler

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"

	"trashbounty/internal/model"
	"trashbounty/internal/repository"
	"trashbounty/internal/service"
	"trashbounty/internal/service/ai"
	"trashbounty/pkg/response"
	"trashbounty/pkg/upload"
)

type TelegramInternalHandler struct {
	UserRepo     *repository.UserRepo
	StatsRepo    *repository.StatsRepo
	BountySvc    *service.BountyService
	ReportSvc    *service.ReportService
	ReportRepo   *repository.ReportRepo
	SupportAgent *ai.SupportAgent
	SharedSecret string
}

func NewTelegramInternalHandler(userRepo *repository.UserRepo, statsRepo *repository.StatsRepo, bountySvc *service.BountyService, reportSvc *service.ReportService, reportRepo *repository.ReportRepo, supportAgent *ai.SupportAgent, sharedSecret string) *TelegramInternalHandler {
	return &TelegramInternalHandler{
		UserRepo:     userRepo,
		StatsRepo:    statsRepo,
		BountySvc:    bountySvc,
		ReportSvc:    reportSvc,
		ReportRepo:   reportRepo,
		SupportAgent: supportAgent,
		SharedSecret: sharedSecret,
	}
}

func (h *TelegramInternalHandler) Status(w http.ResponseWriter, r *http.Request) {
	if !h.authorize(w, r) {
		return
	}

	user, ok := h.loadUserByChatID(w, r)
	if !ok {
		return
	}

	stats, err := h.StatsRepo.GetHomeStats(r.Context(), user.ID)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "gagal mengambil status pengguna")
		return
	}

	response.JSON(w, http.StatusOK, map[string]any{
		"user": map[string]any{
			"id":    user.ID,
			"name":  user.Name,
			"email": user.Email,
			"role":  user.Role,
		},
		"stats": stats,
	})
}

func (h *TelegramInternalHandler) Recommended(w http.ResponseWriter, r *http.Request) {
	if !h.authorize(w, r) {
		return
	}

	user, ok := h.loadUserByChatID(w, r)
	if !ok {
		return
	}

	latStr := r.URL.Query().Get("lat")
	lonStr := r.URL.Query().Get("lon")
	if latStr == "" || lonStr == "" {
		response.Error(w, http.StatusBadRequest, "lat dan lon wajib diisi")
		return
	}

	lat, err := strconv.ParseFloat(latStr, 64)
	if err != nil {
		response.Error(w, http.StatusBadRequest, "lat tidak valid")
		return
	}
	lon, err := strconv.ParseFloat(lonStr, 64)
	if err != nil {
		response.Error(w, http.StatusBadRequest, "lon tidak valid")
		return
	}

	limit, _ := parsePagination(r)
	recommendations, err := h.BountySvc.Recommended(r.Context(), user.ID, lat, lon, limit)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "gagal mengambil rekomendasi bounty")
		return
	}

	response.JSON(w, http.StatusOK, recommendations)
}

func (h *TelegramInternalHandler) Support(w http.ResponseWriter, r *http.Request) {
	if !h.authorize(w, r) {
		return
	}

	var body struct {
		Messages []ai.ChatMessage `json:"messages"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		response.Error(w, http.StatusBadRequest, "request body tidak valid")
		return
	}
	if len(body.Messages) == 0 {
		response.Error(w, http.StatusBadRequest, "messages wajib diisi")
		return
	}

	reply, err := h.SupportAgent.Chat(body.Messages)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "gagal memproses support chat")
		return
	}

	response.JSON(w, http.StatusOK, map[string]string{"reply": reply})
}

func (h *TelegramInternalHandler) CreateReport(w http.ResponseWriter, r *http.Request) {
	if !h.authorize(w, r) {
		return
	}

	user, ok := h.loadUserByChatID(w, r)
	if !ok {
		return
	}

	if err := r.ParseMultipartForm(upload.MaxUploadSize); err != nil {
		response.Error(w, http.StatusBadRequest, "form tidak valid")
		return
	}

	locationText := r.FormValue("location_text")
	latStr := r.FormValue("latitude")
	lonStr := r.FormValue("longitude")
	if locationText == "" {
		response.Error(w, http.StatusBadRequest, "location_text wajib diisi")
		return
	}

	lat, err := strconv.ParseFloat(latStr, 64)
	if err != nil {
		response.Error(w, http.StatusBadRequest, "latitude tidak valid")
		return
	}
	lon, err := strconv.ParseFloat(lonStr, 64)
	if err != nil {
		response.Error(w, http.StatusBadRequest, "longitude tidak valid")
		return
	}

	file, header, err := r.FormFile("image")
	if err != nil {
		response.Error(w, http.StatusBadRequest, "gambar wajib diupload")
		return
	}
	defer file.Close()

	_, imageURL, err := upload.SaveImage(file, header)
	if err != nil {
		response.Error(w, http.StatusBadRequest, err.Error())
		return
	}

	report, err := h.ReportSvc.Create(r.Context(), user.ID, imageURL, lat, lon, locationText)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}

	response.JSON(w, http.StatusAccepted, map[string]any{
		"report_id": report.ID,
		"status":    "ai_analyzing",
		"message":   "Laporan Telegram diterima dan sedang dianalisis oleh AI",
	})
}

func (h *TelegramInternalHandler) Unlink(w http.ResponseWriter, r *http.Request) {
	if !h.authorize(w, r) {
		return
	}

	user, ok := h.loadUserByChatID(w, r)
	if !ok {
		return
	}

	if err := h.UserRepo.UnlinkTelegramChat(r.Context(), user.ID); err != nil {
		response.Error(w, http.StatusInternalServerError, "gagal memutuskan akun telegram")
		return
	}

	response.JSON(w, http.StatusOK, map[string]string{"message": "akun telegram berhasil diputuskan"})
}

func (h *TelegramInternalHandler) Bounties(w http.ResponseWriter, r *http.Request) {
	if !h.authorize(w, r) {
		return
	}

	user, ok := h.loadUserByChatID(w, r)
	if !ok {
		return
	}

	limit, _ := parsePagination(r)
	created, err := h.BountySvc.ListByReporter(r.Context(), user.ID, limit, 0)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "gagal mengambil bounty yang dibuat")
		return
	}
	assigned, err := h.BountySvc.ListByExecutor(r.Context(), user.ID, limit, 0)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "gagal mengambil bounty yang diambil")
		return
	}
	if created == nil {
		created = []model.BountySummary{}
	}
	if assigned == nil {
		assigned = []model.BountySummary{}
	}

	response.JSON(w, http.StatusOK, map[string]any{
		"created":  created,
		"assigned": assigned,
	})
}

func (h *TelegramInternalHandler) ListReports(w http.ResponseWriter, r *http.Request) {
	if !h.authorize(w, r) {
		return
	}

	user, ok := h.loadUserByChatID(w, r)
	if !ok {
		return
	}

	limit, offset := parsePagination(r)
	reports, err := h.ReportSvc.ListByUser(r.Context(), user.ID, limit, offset)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "gagal mengambil daftar laporan")
		return
	}

	response.JSON(w, http.StatusOK, reports)
}

func (h *TelegramInternalHandler) ReportStatus(w http.ResponseWriter, r *http.Request) {
	if !h.authorize(w, r) {
		return
	}

	user, ok := h.loadUserByChatID(w, r)
	if !ok {
		return
	}

	reportID := r.PathValue("reportID")
	if reportID == "" {
		response.Error(w, http.StatusBadRequest, "reportID wajib diisi")
		return
	}

	report, err := h.ReportRepo.GetByID(r.Context(), reportID)
	if err != nil {
		if err == sql.ErrNoRows {
			response.Error(w, http.StatusNotFound, "laporan tidak ditemukan")
			return
		}
		response.Error(w, http.StatusInternalServerError, "gagal mengambil status laporan")
		return
	}
	if report.ReporterID != user.ID {
		response.Error(w, http.StatusForbidden, "laporan bukan milik akun ini")
		return
	}

	progress := 0
	switch report.Status {
	case "pending":
		progress = 0
	case "ai_analyzing":
		progress = 50
	case "approved", "rejected", "bounty_created", "completed":
		progress = 100
	}

	response.JSON(w, http.StatusOK, map[string]any{
		"id":            report.ID,
		"location_text": report.LocationText,
		"status":        report.Status,
		"progress":      progress,
		"waste_type":    report.WasteType,
		"severity":      report.Severity,
		"points_earned": report.PointsEarned,
		"reward_idr":    report.RewardIDR,
		"ai_reasoning":  report.AiReasoning,
		"created_at":    report.CreatedAt,
	})
}

func (h *TelegramInternalHandler) authorize(w http.ResponseWriter, r *http.Request) bool {
	if h.SharedSecret == "" || r.Header.Get("X-Internal-Secret") != h.SharedSecret {
		response.Error(w, http.StatusUnauthorized, "akses internal tidak valid")
		return false
	}
	return true
}

func (h *TelegramInternalHandler) loadUserByChatID(w http.ResponseWriter, r *http.Request) (*model.User, bool) {
	chatID := r.PathValue("chatID")
	if chatID == "" {
		response.Error(w, http.StatusBadRequest, "chatID wajib diisi")
		return nil, false
	}

	user, err := h.UserRepo.GetByTelegramChatID(r.Context(), chatID)
	if err != nil {
		if err == sql.ErrNoRows {
			response.Error(w, http.StatusNotFound, "akun telegram belum terhubung")
			return nil, false
		}
		response.Error(w, http.StatusInternalServerError, "gagal mengambil akun telegram")
		return nil, false
	}
	return user, true
}
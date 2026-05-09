package handler

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"github.com/google/uuid"

	"trashbounty/internal/middleware"
	"trashbounty/internal/repository"
	"trashbounty/pkg/response"
)

type TelegramHandler struct {
	UserRepo *repository.UserRepo
}

func NewTelegramHandler(userRepo *repository.UserRepo) *TelegramHandler {
	return &TelegramHandler{UserRepo: userRepo}
}

func (h *TelegramHandler) GenerateToken(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	token := uuid.NewString()

	if err := h.UserRepo.UpdateTelegramLinkToken(r.Context(), userID, token); err != nil {
		response.Error(w, http.StatusInternalServerError, "gagal membuat token telegram")
		return
	}

	response.JSON(w, http.StatusOK, map[string]string{"token": token})
}

func (h *TelegramHandler) Link(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Token          string `json:"token"`
		TelegramChatID string `json:"telegram_chat_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		response.Error(w, http.StatusBadRequest, "request body tidak valid")
		return
	}
	if body.Token == "" || body.TelegramChatID == "" {
		response.Error(w, http.StatusBadRequest, "token dan telegram_chat_id wajib diisi")
		return
	}

	user, err := h.UserRepo.GetByTelegramLinkToken(r.Context(), body.Token)
	if err != nil {
		if err == sql.ErrNoRows {
			response.Error(w, http.StatusBadRequest, "token telegram tidak valid")
			return
		}
		response.Error(w, http.StatusInternalServerError, "gagal memverifikasi token telegram")
		return
	}

	if err := h.UserRepo.LinkTelegramChat(r.Context(), user.ID, body.TelegramChatID); err != nil {
		response.Error(w, http.StatusInternalServerError, "gagal menghubungkan akun telegram")
		return
	}

	response.JSON(w, http.StatusOK, map[string]string{"message": "akun telegram berhasil terhubung"})
}

func (h *TelegramHandler) Unlink(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())

	if err := h.UserRepo.UnlinkTelegramChat(r.Context(), userID); err != nil {
		response.Error(w, http.StatusInternalServerError, "gagal memutuskan akun telegram")
		return
	}

	response.JSON(w, http.StatusOK, map[string]string{"message": "akun telegram berhasil diputuskan"})
}
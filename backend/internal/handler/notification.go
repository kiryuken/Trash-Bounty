package handler

import (
	"net/http"

	"trashbounty/internal/middleware"
	"trashbounty/internal/repository"
	"trashbounty/pkg/response"
)

type NotificationHandler struct {
	NotifRepo *repository.NotificationRepo
}

func NewNotificationHandler(notifRepo *repository.NotificationRepo) *NotificationHandler {
	return &NotificationHandler{NotifRepo: notifRepo}
}

func (h *NotificationHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	limit, offset := parsePagination(r)

	notifications, err := h.NotifRepo.ListByUser(r.Context(), userID, limit, offset)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	response.JSON(w, http.StatusOK, notifications)
}

func (h *NotificationHandler) MarkRead(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	id := r.PathValue("id")

	if err := h.NotifRepo.MarkRead(r.Context(), id, userID); err != nil {
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	response.JSON(w, http.StatusOK, map[string]string{"message": "notifikasi dibaca"})
}

func (h *NotificationHandler) MarkAllRead(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())

	if err := h.NotifRepo.MarkAllRead(r.Context(), userID); err != nil {
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	response.JSON(w, http.StatusOK, map[string]string{"message": "semua notifikasi dibaca"})
}

func (h *NotificationHandler) UnreadCount(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())

	count, err := h.NotifRepo.UnreadCount(r.Context(), userID)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	response.JSON(w, http.StatusOK, map[string]int{"count": count})
}

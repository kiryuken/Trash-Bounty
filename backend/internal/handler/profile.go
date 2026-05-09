package handler

import (
	"encoding/json"
	"net/http"

	"trashbounty/internal/middleware"
	"trashbounty/internal/service"
	"trashbounty/pkg/response"
)

type ProfileHandler struct {
	ProfileSvc *service.ProfileService
}

func NewProfileHandler(profileSvc *service.ProfileService) *ProfileHandler {
	return &ProfileHandler{ProfileSvc: profileSvc}
}

func (h *ProfileHandler) GetProfile(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	profile, err := h.ProfileSvc.GetProfile(r.Context(), userID)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	response.JSON(w, http.StatusOK, profile)
}

func (h *ProfileHandler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())

	var body struct {
		Name      string  `json:"name"`
		AvatarURL *string `json:"avatar_url"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		response.Error(w, http.StatusBadRequest, "request body tidak valid")
		return
	}

	if body.Name == "" {
		response.Error(w, http.StatusBadRequest, "nama wajib diisi")
		return
	}

	if err := h.ProfileSvc.UpdateProfile(r.Context(), userID, body.Name, body.AvatarURL); err != nil {
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}

	response.JSON(w, http.StatusOK, map[string]string{"message": "profil berhasil diupdate"})
}

func (h *ProfileHandler) GetPrivacy(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	privacy, err := h.ProfileSvc.GetPrivacy(r.Context(), userID)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	response.JSON(w, http.StatusOK, privacy)
}

func (h *ProfileHandler) UpdatePrivacy(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())

	var body struct {
		PublicProfile    bool `json:"public_profile"`
		LocationSharing  bool `json:"location_sharing"`
		TwoFactorEnabled bool `json:"two_factor_enabled"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		response.Error(w, http.StatusBadRequest, "request body tidak valid")
		return
	}

	if err := h.ProfileSvc.UpdatePrivacy(r.Context(), userID, body.PublicProfile, body.LocationSharing, body.TwoFactorEnabled); err != nil {
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}

	response.JSON(w, http.StatusOK, map[string]string{"message": "pengaturan privasi berhasil diupdate"})
}

func (h *ProfileHandler) ChangePassword(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())

	var body struct {
		OldPassword string `json:"current_password"`
		NewPassword string `json:"new_password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		response.Error(w, http.StatusBadRequest, "request body tidak valid")
		return
	}

	if body.OldPassword == "" || body.NewPassword == "" {
		response.Error(w, http.StatusBadRequest, "password lama dan baru wajib diisi")
		return
	}

	if err := h.ProfileSvc.ChangePassword(r.Context(), userID, body.OldPassword, body.NewPassword); err != nil {
		response.Error(w, http.StatusBadRequest, err.Error())
		return
	}

	response.JSON(w, http.StatusOK, map[string]string{"message": "password berhasil diubah"})
}

func (h *ProfileHandler) GetAchievements(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	achievements, err := h.ProfileSvc.GetAchievements(r.Context(), userID)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	response.JSON(w, http.StatusOK, achievements)
}

func (h *ProfileHandler) GetHistory(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	limit, offset := parsePagination(r)
	history, err := h.ProfileSvc.GetHistory(r.Context(), userID, limit, offset)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	response.JSON(w, http.StatusOK, history)
}

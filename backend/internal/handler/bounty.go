package handler

import (
	"net/http"
	"strconv"

	"trashbounty/internal/middleware"
	"trashbounty/internal/service"
	"trashbounty/pkg/response"
	"trashbounty/pkg/upload"
)

type BountyHandler struct {
	BountySvc *service.BountyService
}

func NewBountyHandler(bountySvc *service.BountyService) *BountyHandler {
	return &BountyHandler{BountySvc: bountySvc}
}

func (h *BountyHandler) ListOpen(w http.ResponseWriter, r *http.Request) {
	limit, offset := parsePagination(r)
	bounties, err := h.BountySvc.ListOpen(r.Context(), limit, offset)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	response.JSON(w, http.StatusOK, bounties)
}

func (h *BountyHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	bounty, err := h.BountySvc.GetByID(r.Context(), id)
	if err != nil {
		response.Error(w, http.StatusNotFound, "bounty tidak ditemukan")
		return
	}
	response.JSON(w, http.StatusOK, bounty)
}

func (h *BountyHandler) RecommendedBounties(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
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
	recommendations, err := h.BountySvc.Recommended(r.Context(), userID, lat, lon, limit)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	response.JSON(w, http.StatusOK, recommendations)
}

func (h *BountyHandler) Take(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	bountyID := r.PathValue("id")

	if err := h.BountySvc.Take(r.Context(), bountyID, userID); err != nil {
		response.Error(w, http.StatusBadRequest, err.Error())
		return
	}

	response.JSON(w, http.StatusOK, map[string]string{"message": "bounty berhasil diambil"})
}

func (h *BountyHandler) Complete(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	bountyID := r.PathValue("id")

	if err := r.ParseMultipartForm(upload.MaxUploadSize); err != nil {
		response.Error(w, http.StatusBadRequest, "form tidak valid")
		return
	}

	file, header, err := r.FormFile("proof_image")
	if err != nil {
		response.Error(w, http.StatusBadRequest, "bukti foto wajib diupload")
		return
	}
	defer file.Close()

	_, proofURL, err := upload.SaveImage(file, header)
	if err != nil {
		response.Error(w, http.StatusBadRequest, err.Error())
		return
	}

	if err := h.BountySvc.Complete(r.Context(), bountyID, userID, proofURL); err != nil {
		response.Error(w, http.StatusBadRequest, err.Error())
		return
	}

	response.JSON(w, http.StatusOK, map[string]string{"message": "bounty berhasil diselesaikan"})
}

func (h *BountyHandler) ListMyBounties(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	limit, offset := parsePagination(r)
	bounties, err := h.BountySvc.ListByExecutor(r.Context(), userID, limit, offset)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	response.JSON(w, http.StatusOK, bounties)
}

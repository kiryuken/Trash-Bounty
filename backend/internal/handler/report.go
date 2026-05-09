package handler

import (
	"net/http"
	"strconv"

	"trashbounty/internal/middleware"
	"trashbounty/internal/service"
	"trashbounty/pkg/response"
	"trashbounty/pkg/upload"
)

type ReportHandler struct {
	ReportSvc *service.ReportService
}

func NewReportHandler(reportSvc *service.ReportService) *ReportHandler {
	return &ReportHandler{ReportSvc: reportSvc}
}

func (h *ReportHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())

	if err := r.ParseMultipartForm(upload.MaxUploadSize); err != nil {
		response.Error(w, http.StatusBadRequest, "form tidak valid")
		return
	}

	locationText := r.FormValue("location_text")
	latStr := r.FormValue("latitude")
	lngStr := r.FormValue("longitude")

	if locationText == "" {
		response.Error(w, http.StatusBadRequest, "location_text wajib diisi")
		return
	}

	lat, err := strconv.ParseFloat(latStr, 64)
	if err != nil {
		response.Error(w, http.StatusBadRequest, "latitude tidak valid")
		return
	}
	lng, err := strconv.ParseFloat(lngStr, 64)
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

	report, err := h.ReportSvc.Create(r.Context(), userID, imageURL, lat, lng, locationText)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}

	response.JSON(w, http.StatusAccepted, map[string]any{
		"report_id": report.ID,
		"status":    "ai_analyzing",
		"message":   "Laporan diterima dan sedang dianalisis oleh AI",
	})
}

func (h *ReportHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	id := r.PathValue("id")
	report, err := h.ReportSvc.GetByIDForUser(r.Context(), id, userID)
	if err != nil {
		response.Error(w, http.StatusNotFound, "laporan tidak ditemukan")
		return
	}
	response.JSON(w, http.StatusOK, report)
}

func (h *ReportHandler) GetStatus(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	id := r.PathValue("id")
	report, err := h.ReportSvc.GetByIDForUser(r.Context(), id, userID)
	if err != nil {
		response.Error(w, http.StatusNotFound, "laporan tidak ditemukan")
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
		"status":   report.Status,
		"progress": progress,
	})
}

func (h *ReportHandler) ListMine(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	limit, offset := parsePagination(r)

	reports, err := h.ReportSvc.ListByUser(r.Context(), userID, limit, offset)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	response.JSON(w, http.StatusOK, reports)
}

func (h *ReportHandler) ListRecent(w http.ResponseWriter, r *http.Request) {
	limit, offset := parsePagination(r)

	reports, err := h.ReportSvc.ListRecent(r.Context(), limit, offset)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	response.JSON(w, http.StatusOK, reports)
}

func parsePagination(r *http.Request) (int, int) {
	limit := 20
	offset := 0
	if l := r.URL.Query().Get("limit"); l != "" {
		if v, err := strconv.Atoi(l); err == nil && v > 0 && v <= 100 {
			limit = v
		}
	}
	if o := r.URL.Query().Get("offset"); o != "" {
		if v, err := strconv.Atoi(o); err == nil && v >= 0 {
			offset = v
		}
	}
	return limit, offset
}

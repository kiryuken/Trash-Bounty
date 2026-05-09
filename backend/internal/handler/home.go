package handler

import (
	"net/http"

	"trashbounty/internal/middleware"
	"trashbounty/internal/repository"
	"trashbounty/pkg/response"
)

type HomeHandler struct {
	StatsRepo  *repository.StatsRepo
	ReportRepo *repository.ReportRepo
	BountyRepo *repository.BountyRepo
}

func NewHomeHandler(statsRepo *repository.StatsRepo, reportRepo *repository.ReportRepo, bountyRepo *repository.BountyRepo) *HomeHandler {
	return &HomeHandler{StatsRepo: statsRepo, ReportRepo: reportRepo, BountyRepo: bountyRepo}
}

func (h *HomeHandler) Dashboard(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())

	stats, err := h.StatsRepo.GetHomeStats(r.Context(), userID)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}

	recentReports, _ := h.ReportRepo.ListRecent(r.Context(), 5, 0)
	recentBounties, _ := h.BountyRepo.ListOpen(r.Context(), 5, 0)

	response.JSON(w, http.StatusOK, map[string]any{
		"stats":           stats,
		"recent_reports":  recentReports,
		"recent_bounties": recentBounties,
	})
}

type TransactionHandler struct {
	TxRepo *repository.TransactionRepo
}

func NewTransactionHandler(txRepo *repository.TransactionRepo) *TransactionHandler {
	return &TransactionHandler{TxRepo: txRepo}
}

func (h *TransactionHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	limit, offset := parsePagination(r)

	txs, err := h.TxRepo.ListByUser(r.Context(), userID, limit, offset)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	response.JSON(w, http.StatusOK, txs)
}

func HealthCheck(w http.ResponseWriter, r *http.Request) {
	response.JSON(w, http.StatusOK, map[string]string{"status": "ok", "version": "1.0.0"})
}

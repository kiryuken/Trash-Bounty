package handler

import (
	"net/http"
	"strconv"

	"trashbounty/internal/middleware"
	"trashbounty/internal/service"
	"trashbounty/pkg/response"
)

type LeaderboardHandler struct {
	LeaderboardSvc *service.LeaderboardService
}

func NewLeaderboardHandler(lbSvc *service.LeaderboardService) *LeaderboardHandler {
	return &LeaderboardHandler{LeaderboardSvc: lbSvc}
}

func (h *LeaderboardHandler) Get(w http.ResponseWriter, r *http.Request) {
	period := r.URL.Query().Get("period")
	if period == "" {
		period = "alltime"
	}
	if period != "weekly" && period != "monthly" && period != "alltime" {
		response.Error(w, http.StatusBadRequest, "period harus weekly, monthly, atau alltime")
		return
	}

	role := r.URL.Query().Get("role")
	if role != "" && role != "all" && role != "reporter" && role != "executor" {
		response.Error(w, http.StatusBadRequest, "role harus all, reporter, atau executor")
		return
	}

	limit := 50
	if l := r.URL.Query().Get("limit"); l != "" {
		if v, err := strconv.Atoi(l); err == nil && v > 0 && v <= 100 {
			limit = v
		}
	}

	// Get current user ID from context (optional, leaderboard may be public)
	currentUserID := middleware.GetUserID(r.Context())

	result, err := h.LeaderboardSvc.GetLeaderboard(r.Context(), period, limit, role, currentUserID)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	response.JSON(w, http.StatusOK, result)
}

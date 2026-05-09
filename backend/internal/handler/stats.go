package handler

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"time"

	"trashbounty/internal/repository"
	"trashbounty/pkg/response"
)

type StatsHandler struct {
	StatsRepo            *repository.StatsRepo
	AgentsInternalURL    string
	AgentsInternalSecret string
}

func NewStatsHandler(statsRepo *repository.StatsRepo, agentsInternalURL, agentsInternalSecret string) *StatsHandler {
	return &StatsHandler{
		StatsRepo:            statsRepo,
		AgentsInternalURL:    strings.TrimRight(agentsInternalURL, "/"),
		AgentsInternalSecret: agentsInternalSecret,
	}
}

func (h *StatsHandler) GetCleanupStats(w http.ResponseWriter, r *http.Request) {
	period := r.URL.Query().Get("period")
	if period == "" {
		period = "alltime"
	}
	if period != "weekly" && period != "monthly" && period != "alltime" {
		response.Error(w, http.StatusBadRequest, "period harus weekly, monthly, atau alltime")
		return
	}

	stats, err := h.StatsRepo.GetGlobalCleanupStats(r.Context(), period)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}

	wasteTypes, err := h.StatsRepo.GetWasteTypeBreakdown(r.Context(), period)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}
	stats.WasteTypes = wasteTypes

	response.JSON(w, http.StatusOK, stats)
}

func (h *StatsHandler) GenerateReport(w http.ResponseWriter, r *http.Request) {
	period := r.URL.Query().Get("period")
	if period == "" {
		period = "monthly"
	}
	if period != "weekly" && period != "monthly" && period != "alltime" {
		response.Error(w, http.StatusBadRequest, "period harus weekly, monthly, atau alltime")
		return
	}
	if h.AgentsInternalURL == "" {
		response.Error(w, http.StatusServiceUnavailable, "agents service belum dikonfigurasi")
		return
	}

	body, err := json.Marshal(map[string]string{"period": period})
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "gagal menyiapkan request laporan")
		return
	}

	req, err := http.NewRequestWithContext(r.Context(), http.MethodPost, h.AgentsInternalURL+"/generate-report", bytes.NewReader(body))
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "gagal membuat request ke agents service")
		return
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Internal-Secret", h.AgentsInternalSecret)

	client := &http.Client{Timeout: 120 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		response.Error(w, http.StatusBadGateway, "gagal membuat laporan")
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		response.Error(w, http.StatusBadGateway, "gagal membuat laporan")
		return
	}

	w.Header().Set("Content-Type", "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
	w.Header().Set("Content-Disposition", "attachment; filename=\"laporan-trashbounty-"+period+".docx\"")
	w.WriteHeader(http.StatusOK)
	if _, err := io.Copy(w, resp.Body); err != nil {
		response.Error(w, http.StatusBadGateway, "gagal mengirim dokumen laporan")
	}
}

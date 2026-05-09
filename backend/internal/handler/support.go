package handler

import (
	"encoding/json"
	"net/http"

	"trashbounty/internal/service/ai"
	"trashbounty/pkg/response"
)

type SupportHandler struct {
	SupportAgent *ai.SupportAgent
}

func NewSupportHandler(supportAgent *ai.SupportAgent) *SupportHandler {
	return &SupportHandler{SupportAgent: supportAgent}
}

func (h *SupportHandler) Chat(w http.ResponseWriter, r *http.Request) {
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
		response.Error(w, http.StatusInternalServerError, err.Error())
		return
	}

	response.JSON(w, http.StatusOK, map[string]string{"reply": reply})
}
package ai

import (
	"encoding/json"
	"fmt"
	"strings"
)

type WasteAgentResult struct {
	WasteType  string  `json:"waste_type"`
	Severity   int     `json:"severity"`
	Confidence float64 `json:"confidence"`
	Reasoning  string  `json:"reasoning"`
}

type WasteAgent struct {
	Client *OpenAIClient
	Model  string
}

func NewWasteAgent(client *OpenAIClient, model string) *WasteAgent {
	return &WasteAgent{Client: client, Model: model}
}

func (a *WasteAgent) Analyze(imageURL, title, description, address string) (*WasteAgentResult, string, error) {
	systemPrompt := `Kamu adalah AI Waste Classification Agent dengan kemampuan vision. Tugasmu menganalisis FOTO sampah secara langsung.

Klasifikasikan berdasarkan apa yang kamu lihat di foto:
- waste_type: organic | plastic | metal | glass | electronic | hazardous | mixed | other
- severity: 1-10 (1=sedikit bersih, 10=sangat parah/berbahaya)
- confidence: 0.0-1.0 (seberapa yakin kamu berdasarkan foto)
- reasoning: penjelasan singkat dalam Bahasa Indonesia tentang apa yang terlihat di foto

Respond ONLY in valid JSON:
{
  "waste_type": "string",
  "severity": number,
  "confidence": number,
  "reasoning": "string"
}`

	userText := fmt.Sprintf("Lokasi: %s", address)
	if title != "" && title != address {
		userText = fmt.Sprintf("Judul: %s\nLokasi: %s", title, address)
	}
	if description != "" {
		userText += "\nDeskripsi: " + description
	}
	userText += "\n\nAnalisis foto sampah di atas dan berikan klasifikasi."

	dataURL, err := readImageAsDataURL(imageURL)
	if err != nil {
		return nil, "", fmt.Errorf("baca gambar untuk vision: %w", err)
	}

	rawResp, err := a.Client.ChatWithVision(a.Model, systemPrompt, userText, dataURL, 0.3)
	if err != nil {
		return nil, "", fmt.Errorf("waste agent vision call: %w", err)
	}

	cleaned := cleanJSON(rawResp)
	var result WasteAgentResult
	if err := json.Unmarshal([]byte(cleaned), &result); err != nil {
		return nil, rawResp, fmt.Errorf("parse waste result: %w (raw: %s)", err, rawResp)
	}

	if result.Confidence < 0 {
		result.Confidence = 0
	}
	if result.Confidence > 1 {
		result.Confidence = 1
	}
	if result.Severity < 1 {
		result.Severity = 1
	}
	if result.Severity > 10 {
		result.Severity = 10
	}

	return &result, rawResp, nil
}

func cleanJSON(s string) string {
	s = strings.TrimSpace(s)
	if strings.HasPrefix(s, "```json") {
		s = strings.TrimPrefix(s, "```json")
		s = strings.TrimSuffix(s, "```")
		s = strings.TrimSpace(s)
	} else if strings.HasPrefix(s, "```") {
		s = strings.TrimPrefix(s, "```")
		s = strings.TrimSuffix(s, "```")
		s = strings.TrimSpace(s)
	}
	return s
}

package ai

import (
	"encoding/json"
	"fmt"
)

type CompletionVerificationResult struct {
	Approved   bool    `json:"approved"`
	Confidence float64 `json:"confidence"`
	Reasoning  string  `json:"reasoning"`
}

type CompletionVerificationAgent struct {
	Client *OpenAIClient
	Model  string
}

func NewCompletionVerificationAgent(client *OpenAIClient, model string) *CompletionVerificationAgent {
	return &CompletionVerificationAgent{Client: client, Model: model}
}

func (a *CompletionVerificationAgent) Verify(originalImageURL, proofImageURL, locationText, wasteType string) (*CompletionVerificationResult, error) {
	systemPrompt := `Kamu adalah AI Bounty Completion Verification Agent dengan kemampuan vision. Tugasmu membandingkan dua foto:
1. FOTO ORIGINAL: kondisi lokasi saat sampah pertama kali dilaporkan
2. FOTO BUKTI: kondisi lokasi setelah executor mengklaim sudah membersihkan area

Nilai apakah area yang sama sudah dibersihkan secara signifikan. Perhatikan:
- pengurangan volume sampah yang jelas
- area/lokasi tampak sama atau sangat mirip
- kondisi akhir terlihat lebih bersih daripada foto original
- jangan approve bila foto bukti tidak relevan, beda lokasi, atau perubahannya tidak meyakinkan

Respond ONLY in valid JSON:
{
  "approved": boolean,
  "confidence": number,
  "reasoning": "string"
}`

	userText := fmt.Sprintf(
		"Lokasi: %s\nTipe sampah: %s\n\nBandingkan dua foto yang diberikan. Apakah foto bukti menunjukkan area ini sudah dibersihkan secara signifikan?",
		locationText,
		wasteType,
	)

	originalDataURL, err := readImageAsDataURL(originalImageURL)
	if err != nil {
		return nil, fmt.Errorf("baca gambar original: %w", err)
	}
	proofDataURL, err := readImageAsDataURL(proofImageURL)
	if err != nil {
		return nil, fmt.Errorf("baca gambar bukti: %w", err)
	}

	rawResp, err := a.Client.ChatWithTwoImages(a.Model, systemPrompt, userText, originalDataURL, proofDataURL, 0.2)
	if err != nil {
		return nil, fmt.Errorf("completion verification vision call: %w", err)
	}

	cleaned := cleanJSON(rawResp)
	var result CompletionVerificationResult
	if err := json.Unmarshal([]byte(cleaned), &result); err != nil {
		return nil, fmt.Errorf("parse completion verification result: %w (raw: %s)", err, rawResp)
	}

	if result.Confidence < 0 {
		result.Confidence = 0
	}
	if result.Confidence > 1 {
		result.Confidence = 1
	}

	return &result, nil
}
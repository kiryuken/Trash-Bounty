package ai

import (
	"encoding/json"
	"fmt"
	"math"
)

type RecommendationInput struct {
	ID                   string  `json:"id"`
	WasteType            string  `json:"waste_type"`
	Severity             int     `json:"severity"`
	RewardPoints         int     `json:"reward_points"`
	DistanceKM           float64 `json:"distance_km"`
	EstimatedTimeMinutes int     `json:"estimated_time_minutes"`
}

type BountyRecommendation struct {
	BountyID  string  `json:"bounty_id"`
	Score     float64 `json:"score"`
	Reasoning string  `json:"reasoning"`
}

type RecommenderAgent struct {
	Client *OpenAIClient
	Model  string
}

func NewRecommenderAgent(client *OpenAIClient, model string) *RecommenderAgent {
	return &RecommenderAgent{Client: client, Model: model}
}

func (a *RecommenderAgent) Recommend(executorLat, executorLon float64, pastWasteTypes []string, bounties []RecommendationInput) ([]BountyRecommendation, error) {
	if len(bounties) == 0 {
		return []BountyRecommendation{}, nil
	}

	systemPrompt := `Kamu adalah AI Bounty Recommender untuk TrashBounty. Tugasmu memberi ranking bounty terbaik untuk executor.

Prioritas penilaian:
- Jarak terdekat lebih baik
- Kesesuaian tipe sampah dengan histori executor lebih baik
- Reward points lebih tinggi untuk effort/waktu yang masuk akal lebih baik
- Severity yang sedikit lebih tinggi boleh diprioritaskan jika masih realistis

Kamu HARUS mengembalikan JSON array valid dengan urutan terbaik ke terburuk:
[
  {
    "bounty_id": "string",
    "score": number,
    "reasoning": "string"
  }
]

Gunakan hanya bounty_id yang diberikan. Jangan menambah item baru.`

	userText := fmt.Sprintf(
		"Koordinat executor: %.6f, %.6f\nHistori tipe sampah executor: %s\n\nDaftar bounty kandidat:\n%s",
		executorLat,
		executorLon,
		mustMarshalCompact(pastWasteTypes),
		mustMarshalCompact(bounties),
	)

	rawResp, err := a.Client.Chat(a.Model, []ChatMessage{
		{Role: "system", Content: systemPrompt},
		{Role: "user", Content: userText},
	}, 0.3)
	if err != nil {
		return nil, fmt.Errorf("recommender chat call: %w", err)
	}

	cleaned := cleanJSON(rawResp)
	var result []BountyRecommendation
	if err := json.Unmarshal([]byte(cleaned), &result); err != nil {
		return nil, fmt.Errorf("parse recommender result: %w (raw: %s)", err, rawResp)
	}

	for index := range result {
		if result[index].Score < 0 {
			result[index].Score = 0
		}
	}

	return result, nil
}

func HaversineKM(lat1, lon1, lat2, lon2 float64) float64 {
	const earthRadiusKM = 6371.0
	dLat := degreesToRadians(lat2 - lat1)
	dLon := degreesToRadians(lon2 - lon1)
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(degreesToRadians(lat1))*math.Cos(degreesToRadians(lat2))*
			math.Sin(dLon/2)*math.Sin(dLon/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return earthRadiusKM * c
}

func degreesToRadians(value float64) float64 {
	return value * math.Pi / 180
}

func mustMarshalCompact(value any) string {
	data, err := json.Marshal(value)
	if err != nil {
		return "[]"
	}
	return string(data)
}
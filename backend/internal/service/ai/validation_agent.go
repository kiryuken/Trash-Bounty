package ai

import (
	"encoding/json"
	"fmt"
)

type ValidationResult struct {
	Approved                  bool    `json:"approved"`
	Confidence                float64 `json:"confidence"`
	Reasoning                 string  `json:"reasoning"`
	IndoorOrEnclosed          bool    `json:"indoor_or_enclosed"`
	MunicipalCollectionPoint  bool    `json:"municipal_collection_point"`
}

type ValidationAgent struct {
	Client *OpenAIClient
	Model  string
}

func NewValidationAgent(client *OpenAIClient, model string) *ValidationAgent {
	return &ValidationAgent{Client: client, Model: model}
}

func (a *ValidationAgent) Validate(imageURL, title, description, address string, wasteResult *WasteAgentResult) (*ValidationResult, string, error) {
	systemPrompt := `Kamu adalah AI Validation Agent dengan kemampuan vision. Tugasmu memvalidasi laporan sampah dengan melihat langsung fotonya.

Kamu menerima hasil klasifikasi dari Waste Agent dan FOTO ASLI untuk diverifikasi ulang.

Kriteria approval:
- Foto memang menunjukkan sampah/limbah nyata (bukan foto acak)
- Lokasi terlihat berada di area publik atau semi-publik yang layak dilaporkan, termasuk bahu jalan, trotoar, tepi drainase, tepi jembatan, atau ruang publik lain yang terdampak
- Sampah yang dikantongi, diikat, atau ditumpuk tetap bisa valid jika dibuang sembarangan dan mengotori/mengganggu area publik
- Klasifikasi waste_type dari Waste Agent masuk akal dengan apa yang terlihat
- Confidence waste agent >= 0.5
- Severity >= 2
- Laporan bukan spam atau palsu

Kriteria reject tambahan yang WAJIB ditolak:
- Sampah berada di dalam ruangan, area indoor, gudang, dapur, kantor, rumah, toko, atau ruang tertutup lain
- Sampah JELAS berada di fasilitas pengumpulan resmi seperti TPS, depo sampah, bak sampah komunal, kontainer sampah besar, gerobak resmi, atau titik kumpul yang memang disiapkan untuk diambil oleh dinas kebersihan

Aturan penting:
- Jika terlihat indoor atau ruang tertutup, set approved=false dan indoor_or_enclosed=true
- Hanya set municipal_collection_point=true jika ada indikasi visual kuat fasilitas resmi, misalnya kontainer/bin permanen, papan atau tanda TPS, area penampungan khusus, gerobak/armada kebersihan resmi, atau infrastruktur pengumpulan yang jelas
- JANGAN set municipal_collection_point=true hanya karena sampah berada di pinggir jalan, dekat pagar/bangunan/jembatan, atau karena sampah dikemas dalam kantong/karung tanpa fasilitas resmi yang jelas
- Tumpukan sampah di bahu jalan, trotoar, tepi drainase, tepi jembatan, atau ruang publik lain tetap layak di-approve jika mengotori/mengganggu area publik dan tidak tampak sebagai fasilitas pengumpulan resmi
- Jika salah satu flag di atas true, reasoning harus menjelaskan penolakan itu dengan jelas dalam Bahasa Indonesia
- Jangan menolak hanya karena tumpukan terlihat rapi atau terkonsentrasi; fokus pada apakah itu pembuangan liar yang mengganggu ruang publik
- Hanya set approved=true jika lokasi terlihat sebagai sampah liar, pembuangan sembarangan, atau tumpukan sampah yang mengotori/mengganggu area publik dan bukan fasilitas pengumpulan resmi

Respond ONLY in valid JSON:
{
  "approved": boolean,
  "confidence": number,
	"reasoning": "string",
	"indoor_or_enclosed": boolean,
	"municipal_collection_point": boolean
}`

	wasteJSON, _ := json.Marshal(wasteResult)
	userText := fmt.Sprintf(
		"Lokasi: %s\nHasil Waste Agent:\n%s",
		address, string(wasteJSON),
	)
	if title != "" && title != address {
		userText = fmt.Sprintf(
			"Judul: %s\nLokasi: %s\nHasil Waste Agent:\n%s",
			title, address, string(wasteJSON),
		)
	}
	if description != "" {
		userText += "\nDeskripsi pelapor: " + description
	}
	userText += "\n\nVerifikasi foto di atas: apakah laporan ini valid?"

	dataURL, err := readImageAsDataURL(imageURL)
	if err != nil {
		return nil, "", fmt.Errorf("baca gambar untuk validasi: %w", err)
	}

	rawResp, err := a.Client.ChatWithVision(a.Model, systemPrompt, userText, dataURL, 0.2)
	if err != nil {
		return nil, "", fmt.Errorf("validation agent vision call: %w", err)
	}

	cleaned := cleanJSON(rawResp)
	var result ValidationResult
	if err := json.Unmarshal([]byte(cleaned), &result); err != nil {
		return nil, rawResp, fmt.Errorf("parse validation result: %w (raw: %s)", err, rawResp)
	}

	if result.IndoorOrEnclosed || result.MunicipalCollectionPoint {
		result.Approved = false
	}
	if result.Confidence < 0 {
		result.Confidence = 0
	}
	if result.Confidence > 1 {
		result.Confidence = 1
	}

	return &result, rawResp, nil
}

package ai

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
)

type OpenAIClient struct {
	APIKey     string
	HTTPClient *http.Client
}

func NewOpenAIClient(apiKey string) *OpenAIClient {
	return &OpenAIClient{
		APIKey:     apiKey,
		HTTPClient: &http.Client{Timeout: 90 * time.Second},
	}
}

type ChatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type ChatResponse struct {
	Choices []struct {
		Message ChatMessage `json:"message"`
	} `json:"choices"`
}

// Chat sends a plain-text chat completion request.
func (c *OpenAIClient) Chat(model string, messages []ChatMessage, temperature float64) (string, error) {
	type req struct {
		Model       string        `json:"model"`
		Messages    []ChatMessage `json:"messages"`
		Temperature float64       `json:"temperature"`
	}
	return c.doCompletion(req{Model: model, Messages: messages, Temperature: temperature})
}

// ChatWithVision sends a multimodal chat completion request with an image.
// imageDataURL must be a data URI: "data:image/jpeg;base64,<b64>".
func (c *OpenAIClient) ChatWithVision(model, systemPrompt, userText, imageDataURL string, temperature float64) (string, error) {
	body, err := json.Marshal(map[string]any{
		"model": model,
		"messages": []map[string]any{
			{
				"role":    "system",
				"content": systemPrompt,
			},
			{
				"role": "user",
				"content": []map[string]any{
					{"type": "text", "text": userText},
					{
						"type": "image_url",
						"image_url": map[string]string{
							"url":    imageDataURL,
							"detail": "auto",
						},
					},
				},
			},
		},
		"temperature": temperature,
	})
	if err != nil {
		return "", fmt.Errorf("marshal: %w", err)
	}
	return c.callCompletions(body)
}

// ChatWithTwoImages sends a multimodal chat completion request with two images.
// imageDataURL1 and imageDataURL2 must be data URIs: "data:image/jpeg;base64,<b64>".
func (c *OpenAIClient) ChatWithTwoImages(model, systemPrompt, userText, imageDataURL1, imageDataURL2 string, temperature float64) (string, error) {
	body, err := json.Marshal(map[string]any{
		"model": model,
		"messages": []map[string]any{
			{
				"role":    "system",
				"content": systemPrompt,
			},
			{
				"role": "user",
				"content": []map[string]any{
					{"type": "text", "text": userText},
					{
						"type": "image_url",
						"image_url": map[string]string{
							"url":    imageDataURL1,
							"detail": "auto",
						},
					},
					{
						"type": "image_url",
						"image_url": map[string]string{
							"url":    imageDataURL2,
							"detail": "auto",
						},
					},
				},
			},
		},
		"temperature": temperature,
	})
	if err != nil {
		return "", fmt.Errorf("marshal: %w", err)
	}
	return c.callCompletions(body)
}

// doCompletion is a generic helper for plain JSON bodies.
func (c *OpenAIClient) doCompletion(reqBody any) (string, error) {
	body, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("marshal: %w", err)
	}
	return c.callCompletions(body)
}

func (c *OpenAIClient) callCompletions(body []byte) (string, error) {
	req, err := http.NewRequest("POST", "https://api.openai.com/v1/chat/completions", bytes.NewReader(body))
	if err != nil {
		return "", fmt.Errorf("new request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.APIKey)

	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("http do: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("read body: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("openai error %d: %s", resp.StatusCode, string(respBody))
	}

	var chatResp ChatResponse
	if err := json.Unmarshal(respBody, &chatResp); err != nil {
		return "", fmt.Errorf("unmarshal: %w", err)
	}

	if len(chatResp.Choices) == 0 {
		return "", fmt.Errorf("no choices returned")
	}

	return chatResp.Choices[0].Message.Content, nil
}

// readImageAsDataURL reads a local image file (stored relative path like
// /uploads/reports/file.jpg) and returns a base64 data URI.
func readImageAsDataURL(imageURL string) (string, error) {
	localPath := strings.TrimPrefix(imageURL, "/")

	data, err := os.ReadFile(localPath)
	if err != nil {
		return "", fmt.Errorf("baca file %s: %w", localPath, err)
	}

	mimeType := http.DetectContentType(data)
	switch mimeType {
	case "image/jpeg", "image/png", "image/webp", "image/gif":
		// supported
	default:
		mimeType = "image/jpeg"
	}

	encoded := base64.StdEncoding.EncodeToString(data)
	return fmt.Sprintf("data:%s;base64,%s", mimeType, encoded), nil
}

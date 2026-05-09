package ai

import (
	"encoding/json"
	"fmt"
	"log"

	"trashbounty/internal/model"
)

type Orchestrator struct {
	WasteAgent      *WasteAgent
	ValidationAgent *ValidationAgent
}

func NewOrchestrator(wasteAgent *WasteAgent, validationAgent *ValidationAgent) *Orchestrator {
	return &Orchestrator{
		WasteAgent:      wasteAgent,
		ValidationAgent: validationAgent,
	}
}

func (o *Orchestrator) Process(imageURL, locationText, description, address string) (*model.AIResult, json.RawMessage, json.RawMessage, error) {
	log.Printf("[AI] Starting analysis for location: %s, image: %s", locationText, imageURL)

	// Step 1: Waste classification (gpt-4o-mini)
	wasteResult, miniRaw, err := o.WasteAgent.Analyze(imageURL, locationText, description, address)
	if err != nil {
		return nil, nil, nil, fmt.Errorf("waste analysis: %w", err)
	}
	log.Printf("[AI] Waste result: type=%s severity=%d confidence=%.2f",
		wasteResult.WasteType, wasteResult.Severity, wasteResult.Confidence)

	// Step 2: Validation (gpt-4o)
	valResult, stdRaw, err := o.ValidationAgent.Validate(imageURL, locationText, description, address, wasteResult)
	if err != nil {
		return nil, nil, nil, fmt.Errorf("validation: %w", err)
	}
	log.Printf("[AI] Validation result: approved=%v confidence=%.2f", valResult.Approved, valResult.Confidence)

	// Step 3: Calculate points
	points, idr := CalculatePoints(wasteResult.WasteType, wasteResult.Severity, wasteResult.Confidence)

	result := &model.AIResult{
		WasteType:    wasteResult.WasteType,
		Severity:     wasteResult.Severity,
		Confidence:   wasteResult.Confidence,
		Reasoning:    wasteResult.Reasoning + " | Validasi: " + valResult.Reasoning,
		Approved:     valResult.Approved,
		RewardPoints: points,
		RewardIDR:    idr,
	}

	miniJSON, _ := json.Marshal(map[string]any{
		"raw":    miniRaw,
		"parsed": wasteResult,
	})
	stdJSON, _ := json.Marshal(map[string]any{
		"raw":    stdRaw,
		"parsed": valResult,
	})

	return result, json.RawMessage(miniJSON), json.RawMessage(stdJSON), nil
}

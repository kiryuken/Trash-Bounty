package ai

import "math"

var wasteTypeMultiplier = map[string]float64{
	"hazardous":  1.15,
	"electronic": 1.1,
	"metal":      1.05,
	"plastic":    1.0,
	"glass":      0.95,
	"mixed":      1.0,
	"organic":    0.85,
	"unknown":    0.8,
}

const (
	pointsPerIDR            = 10.0
	pointToIDR              = 1.0 / pointsPerIDR
	rewardPointsPerSeverity = 15000
	minPoints               = 5000
	maxModeratePoints       = 100000
	maxPoints               = 150000
	moderateSeverityCap     = 6
	executorRewardPercent   = 80
)

func CalculatePoints(wasteType string, severity int, confidence float64) (int, float64) {
	severity = clampSeverity(severity)
	confidence = clampConfidence(confidence)

	wm := wasteTypeMultiplier[wasteType]
	if wm == 0 {
		wm = 1.0
	}

	raw := float64(severity*rewardPointsPerSeverity) * wm * confidence
	points := roundPoints(raw)

	if points < minPoints {
		points = minPoints
	}
	if severity <= moderateSeverityCap && points > maxModeratePoints {
		points = maxModeratePoints
	}
	if points > maxPoints {
		points = maxPoints
	}

	idr := PointsToIDR(points)
	return points, idr
}

func PointsToIDR(points int) float64 {
	return math.Round(float64(points)*pointToIDR*100) / 100
}

func SplitBountyReward(totalPoints int) (executorPoints int, executorIDR float64, reporterBonusPoints int, reporterBonusIDR float64) {
	if totalPoints < 0 {
		totalPoints = 0
	}

	executorPoints = (totalPoints * executorRewardPercent) / 100
	reporterBonusPoints = totalPoints - executorPoints

	executorIDR = PointsToIDR(executorPoints)
	reporterBonusIDR = PointsToIDR(reporterBonusPoints)
	return executorPoints, executorIDR, reporterBonusPoints, reporterBonusIDR
}

func clampSeverity(severity int) int {
	if severity < 1 {
		return 1
	}
	if severity > 10 {
		return 10
	}
	return severity
}

func clampConfidence(confidence float64) float64 {
	if confidence < 0.35 {
		return 0.35
	}
	if confidence > 1 {
		return 1
	}
	return confidence
}

func roundPoints(raw float64) int {
	return int(math.Round(raw/100.0) * 100)
}

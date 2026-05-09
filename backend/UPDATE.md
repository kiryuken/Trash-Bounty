# Backend Update — Gap Fix Pass #3

All fixes align the Go backend implementation with the **AGENT_MASTER_PLAN.md** specification.
Build (`go build ./...`) and vet (`go vet ./...`) pass clean after all changes.

---

## Checklist — Pass #3 Fixes

### CRITICAL Fixes
- [x] **C2** — `context.Context` propagated through ALL layers (repo → service → handler)
- [x] **C3** — `sql.NullString`/`NullInt32`/`NullFloat64` replaced with pointer types (`*string`, `*int`, `*float64`) in all models
- [x] **C4** — `imageURL` passed through entire AI pipeline (orchestrator → waste_agent → validation_agent)
- [x] **C6** — AI failure (timeout + error) now sets report status `"rejected"` and sends notification

### MODERATE Fixes
- [x] **M1** — All routes changed from `/api/` prefix to `/v1/`
- [x] **M2** — `GET /v1/leaderboard` moved to protected routes (behind auth middleware)
- [x] **M3** — `GET /v1/reports/{id}` and `GET /v1/bounties/{id}` moved to protected routes
- [x] **M5** — Duplicate email registration returns `409 Conflict` instead of `400`
- [x] **M6** — Password field changed from `old_password` to `current_password`
- [x] **M8** — Home endpoint path changed from `/api/home/dashboard` to `/v1/home/stats`
- [x] **M11** — Added `UserDTO` struct for auth responses (no longer exposes full `model.User`)

### MINOR Fixes
- [x] **m4** — `go.mod` version fixed from `1.25.0` to `1.23.0`

### Deferred (Lower Priority / Structural)
- [ ] **C1** — Switch from `net/http` ServeMux to `chi/v5` router (massive structural refactor, net/http works functionally with Go 1.22+)
- [ ] **C5** — Bounty completion AI verification (new feature, not blocking build)
- [ ] **M4** — Haversine distance calculation for bounty listing (nice-to-have)
- [ ] **M7** — Structured logging with `slog` (cosmetic)
- [ ] **M9** — Home/Notification/Transaction handlers bypass service layer (architectural debt)
- [ ] **M10** — Per-user upload rate limiting (feature)
- [ ] **M12** — Missing `in_progress` state transition for bounties

---

## Detailed Changes — Pass #3

### 1. context.Context Propagation (C2)

All 6 repository files now accept `context.Context` as the first parameter on every method,
using `QueryRowContext`, `ExecContext`, and `QueryContext` instead of their non-context counterparts:

| Repository | Methods Updated |
|---|---|
| `user_repo.go` | Create, GetByID, GetByEmail, AddPoints, AddWallet, GetProfile, UpdateProfile, GetPrivacy, UpdatePrivacy, UpdatePassword, GetHistory, SaveRefreshToken, GetRefreshToken, DeleteRefreshToken |
| `report_repo.go` | Create, GetByID, UpdateStatus, UpdateAIResult, ListByUser, ListRecent, CountByUser |
| `bounty_repo.go` | Create, GetByID, Take, Complete, ListOpen, ListByExecutor, CountCompletedByUser |
| `notification_repo.go` | Create, ListByUser, MarkRead, MarkAllRead, UnreadCount |
| `transaction_repo.go` | Create, ListByUser, Complete |
| `achievement_repo.go` | Grant, ListByUser, GetAchievementDTOs |

Additional repos in `transaction_repo.go`:
- `LeaderboardRepo.GetLeaderboard` — now takes `ctx`
- `StatsRepo.GetHomeStats` — now takes `ctx`

All 4 service files updated to pass `ctx` to every repo call:
- `auth_service.go` — Register, Login, RefreshToken, Logout, generateAuthResponse
- `report_service.go` — Create, processAI, handleAIResult, GetByID, ListByUser, ListRecent, checkReportAchievements, checkPointsAchievements
- `bounty_service.go` — ListOpen, GetByID, Take, Complete, ListByExecutor, checkBountyAchievements, checkPointsAchievements
- `profile_service.go` — GetProfile, UpdateProfile, GetPrivacy, UpdatePrivacy, ChangePassword, GetHistory, GetAchievements
- `LeaderboardService.GetLeaderboard` — now takes `ctx`

All 7 handler files updated to pass `r.Context()`:
- `auth.go`, `report.go`, `bounty.go`, `profile.go`, `home.go`, `notification.go`, `leaderboard.go`

### 2. Model Pointer Types (C3)

| Model | Fields Changed |
|---|---|
| `user.go` | `AvatarURL *string` (was `sql.NullString`) |
| `report.go` | `WasteType *string`, `Severity *int`, `EstimatedWeightKG *float64`, `AiConfidence *float64`, `AiReasoning *string`, `RewardIDR *float64` |
| `bounty.go` | `ExecutorID *string`, `Address *string`, `ProofImageURL *string` |

JSON serialization now correctly outputs `null` instead of `{"String":"","Valid":false}`.

### 3. AI Pipeline Image URL (C4)

- `orchestrator.Process()` — new signature: `(imageURL, locationText, description, address string)`
- `waste_agent.Analyze()` — new signature: `(imageURL, title, description, address string)`, includes `Foto: <url>` in prompt
- `validation_agent.Validate()` — new signature: `(imageURL, title, description, address string, wasteResult)`, includes `Foto: <url>` in prompt
- `report_service.go` — passes `report.ImageURL` to `AI.Process()`

### 4. AI Failure Handling (C6)

`report_service.processAI()`:
- Timeout → sets report status `"rejected"`, sends "Analisis AI gagal (timeout)" notification
- Error → sets report status `"rejected"`, sends "Analisis AI gagal" notification
- Previously: both cases left report in `"pending"` status with no notification

### 5. Route & Auth Fixes (M1, M2, M3, M5, M6, M8)

| Change | Before | After |
|---|---|---|
| Route prefix | `/api/` | `/v1/` |
| Home endpoint | `/api/home/dashboard` | `/v1/home/stats` |
| Leaderboard | public | protected (auth required) |
| Report detail | public | protected |
| Bounty detail | public | protected |
| Duplicate email | `400 Bad Request` | `409 Conflict` |
| Password field | `old_password` | `current_password` |

### 6. Auth Response DTO (M11)

New `UserDTO` struct in `auth_service.go`:
```go
type UserDTO struct {
    ID, Name, Email, Role string
    AvatarURL *string
    Points int
    WalletBalance float64
    Rank *int
}
```
`AuthResponse.User` field is now `UserDTO` (no password hash, no timestamps exposed).

### 7. Go Module Fix (m4)

`go.mod`: `go 1.25.0` → `go 1.23.0` (1.25.0 does not exist)

---

## Previous Passes (Summary)

### Pass #1 — Initial Build
Full backend scaffolding: models, repos, services, handlers, AI pipeline, migrations, Docker setup.

### Pass #2 — Field Alignment
- Removed Title/Description/Address from Report/Bounty, added LocationText
- CreatedBy → ReporterID in Bounty
- SHA-256 refresh token hashing
- AI timeout with context
- Points agent multiplier alignment
- Auth response consolidation
- go.mod version fix

---

## Build Status

```
go build ./...  ✅ PASS
go vet ./...    ✅ PASS
```

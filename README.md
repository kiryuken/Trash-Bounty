# Trash Bounty

Trash Bounty adalah monorepo untuk sistem pelaporan sampah berbasis reward, terdiri dari:

- **backend**: REST API Go untuk auth, laporan, bounty, leaderboard, notifikasi, dan profil
- **frontend**: aplikasi mobile Flutter untuk reporter dan executor
- **agents**: service FastAPI + Telegram bot untuk notifikasi dan pembuatan laporan

## Struktur Repo

```text
.
├── backend/   # API Go + PostgreSQL + Docker compose
├── frontend/  # Aplikasi Flutter
├── agents/    # FastAPI service dan Telegram bot
├── start-services.sh
└── start-services.ps1
```

## Stack

- **Backend**: Go, PostgreSQL, Docker Compose
- **Frontend**: Flutter, Riverpod, GoRouter, Dio
- **Agents**: Python, FastAPI, python-telegram-bot

## Port dan Endpoint Lokal

- Backend lokal default: `http://localhost:8080`
- Health check backend: `GET /v1/health`
- Agents lokal default: `http://localhost:8000/health`
- Frontend Android emulator menggunakan base URL: `http://10.0.2.2:8080/v1`

Gunakan override `8081` hanya jika memang sedang memakai tunnel lokal khusus.

## Menjalankan Backend

```bash
cd backend
cp .env.example .env.local
go test ./...
go run ./cmd/server
```

Alternatif dengan Docker:

```bash
cd backend
docker compose up -d
```

## Menjalankan Frontend

```bash
cd frontend
flutter pub get
flutter test
flutter run
```

## Menjalankan Agents

```bash
cd agents
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env.local
python main.py
```

## Menjalankan Service Helper

Tersedia script root untuk membantu start backend, agents, dan tunnel:

- `./start-services.sh start`
- `./start-services.sh status`
- `./start-services.sh stop`
- `./start-services.ps1`

## Validasi yang Dipakai di Repo

- Backend: `go test ./...` dan `go build ./...`
- Frontend: `flutter test` dan `flutter analyze`

## Catatan

- Seluruh API utama memakai prefix `/v1`
- Backend lokal repo ini diasumsikan berjalan di port `8080`
- Detail implementasi tambahan ada di `backend/UPDATE.md` dan `frontend/UPDATE.md`

.PHONY: dev up down build logs db-shell test tidy

dev:
	go run ./cmd/server

up:
	docker compose up -d

down:
	docker compose down

build:
	docker compose build

logs:
	docker compose logs -f app

db-shell:
	docker exec -it trashbounty_db psql -U trashbounty -d trashbounty_db

test:
	go test ./... -v

tidy:
	go mod tidy

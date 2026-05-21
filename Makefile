.PHONY: up down build restart logs api frontend

## Start everything (rebuild api + frontend)
up:
	docker compose up --build api frontend

## Start only the API (no frontend)
api:
	docker compose up --build api

## Start only the frontend
frontend:
	docker compose up --build frontend

## Build images without starting
build:
	docker compose build api frontend

## Stop all services
down:
	docker compose down

## Restart API only (fast, no rebuild)
restart:
	docker compose restart api

## Tail logs for api and frontend
logs:
	docker compose logs -f api frontend

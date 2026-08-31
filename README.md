# msgr

[![CI](https://github.com/mikalv/msgr/actions/workflows/ci.yaml/badge.svg)](https://github.com/mikalv/msgr/actions/workflows/ci.yaml)
[![Backend coverage](https://img.shields.io/badge/backend%20coverage-CI%20artifact-informational)](backend/coveralls.json)

En eksperimentell norsk meldingstjeneste bygget på en Phoenix-backend og en
Flutter-klient. Repoet er organisert som et monorepo med flere tjenester,
Flutter-appar og støtteverktøy.

## Testing

```bash
# Backend unit tests + coverage (requires local Postgres)
cd backend && mix coveralls.html --umbrella

# Flutter tests + lcov
cd flutter_frontend && flutter test --coverage

# Docker integration tests (CLI against live stack)
bash scripts/ci_integration_env.sh
pytest -m integration -v
```

Coverage threshold for the backend umbrella is configured in
`backend/coveralls.json` (non-regression floor today; target 70% as parked
suites in `**/test/pending_*` are restored). CI uploads `excoveralls.json` and
Flutter `coverage/lcov.info` as workflow artifacts.

## Arkitektur-sjekkliste

- [x] TLS kan slås av/på via miljøvariablene `MSGR_TLS_*` uten kodeendringer
  (se `.env.example` og `backend/config/runtime.exs`).
- [x] Noise-transport og handshake er feature-togglet via `NOISE_*`-variabler og
  håndteres automatisk av `libmsgr_core`.
- [x] Kun én Postgres-instans kjøres i docker-stacken (`services.db`).
- [x] Flutter-klienten følger den planlagte feature-strukturen med egne mapper
  for `auth`, `bridges`, `chat` og `contacts`.
- [x] Krypteringslaget kan byttes ut – Noise/TLS toggles og et modulært
  `libmsgr_core` gjør det mulig å teste alternative transports/FFI-moduler uten
  å endre UI-koden.

## Komme i gang

```bash
cp .env.example .env
# Fill required secrets (SECRET_KEY_BASE, SERVER_STATIC_KEY, …) — see docs/SECRET_MANAGEMENT.md
docker compose up --build
```

Backenden starter da på port `4000` (HTTP) og, dersom TLS er aktivert, på
`4443`. Noise-transporten lytter på `5443` når `NOISE_TRANSPORT_ENABLED=true`.

## Videre lesning

- [architecture.md](architecture.md) – høynivå arkitektur og mål.
- [docs/architecture_alignment.md](docs/architecture_alignment.md) – siste
  status på hvordan kodebasen matcher arkitekturprinsippene.
- [docs/SECRET_MANAGEMENT.md](docs/SECRET_MANAGEMENT.md) – secrets for lokal og prod.
- [docs/ci_and_coverage.md](docs/ci_and_coverage.md) – CI-jobber, coveralls, pending suites.
- [docs/media_virus_scan.md](docs/media_virus_scan.md) – ClamAV-pipeline for team-media.
- [docs/e2ee_spec.md](docs/e2ee_spec.md) – 1:1 E2EE (XX Double Ratchet) normative wire/crypto.
- [docs/e2ee_developer.md](docs/e2ee_developer.md) – E2EE developer runbook (API, client, tests).
- [docs/realtime_channels.md](docs/realtime_channels.md) – Phoenix WS-topics,
  team vs personlig realtime, `RequireTeamMembership`.
- [docs/rtc.md](docs/rtc.md) – WebRTC-signalisering og TURN.
- [backend/README.md](backend/README.md) – detaljer om Docker-stacken og
  backend-konfigurasjon.

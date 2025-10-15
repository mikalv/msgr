# msgr

En eksperimentell norsk meldingstjeneste bygget på en Phoenix-backend og en
Flutter-klient. Repoet er organisert som et monorepo med flere tjenester,
Flutter-appar og støtteverktøy.

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
docker compose up --build
```

Backenden starter da på port `4000` (HTTP) og, dersom TLS er aktivert, på
`4443`. Noise-transporten lytter på `5443` når `NOISE_TRANSPORT_ENABLED=true`.

## Videre lesning

- [architecture.md](architecture.md) – høynivå arkitektur og mål.
- [docs/architecture_alignment.md](docs/architecture_alignment.md) – siste
  status på hvordan kodebasen matcher arkitekturprinsippene.
- [backend/README.md](backend/README.md) – detaljer om Docker-stacken og
  backend-konfigurasjon.

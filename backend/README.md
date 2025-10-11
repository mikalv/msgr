# Messngr.Umbrella

## Utviklingsmiljø med Docker

Dette prosjektet kan kjøres lokalt via Docker for å få en komplett backend-stack
med Postgres og Phoenix.

### Forutsetninger

- [Docker](https://www.docker.com/) og Docker Compose (v2 eller nyere)

### Kommandoer

Fra repo-roten:

```bash
docker compose up --build
```

Første gang tar det noen minutter fordi avhengigheter, npm-verktøy og database
må settes opp. Når containerne er oppe er Phoenix tilgjengelig på
<http://localhost:4000> og hot-reloading fungerer gjennom bind mounts.

### Nyttige volum

Compose-filen deler navngitte volum for `_build`, `deps`, Node-moduler og
Tailwind-cache slik at de gjenbrukes mellom restarter uten å poluere repoet
med maskinspesifikke filer.

### Database

En Postgres 15-instans kjøres automatisk og er tilgjengelig på port 5432. Default
bruker/passord er `postgres`/`postgres`, og databasen heter `msgr_dev`.

### StoneMQ meldingskø

Compose-stacken bygger og starter også en [StoneMQ](https://github.com/jonefeewang/stonemq)
node. Den lyttes på port 9092 og er kompatibel med Kafka-klienter (minimum versjon
0.11). Data for journal, kø og nøkkelverdi-lager persisteres i volumet
`stonemq_data`.

Byggeargumentet `STONEMQ_REF` kan overstyres dersom du ønsker å teste en annen
branch eller commit av StoneMQ-prosjektet:

```bash
docker compose build stonemq --build-arg STONEMQ_REF=<commit-eller-branch>
```

### Observability (Prometheus, Grafana og OpenObserve)

- **Prometheus** skraper metrikker fra Phoenix på `backend:9568` via
  `TelemetryMetricsPrometheus`. Bruk `http://localhost:9090` for å inspisere
  råmetrikker.
- **Grafana** startes med en forhåndsprovisjonert Prometheus-datakilde og er
  tilgjengelig på `http://localhost:3000` (bruker/pass: `admin`/`admin`).
- **OpenObserve** håndterer loggdata på `http://localhost:5080`. Standardbrukeren
  er `root@example.com` med passord `Complexpass#123`.

Backenden publiserer applikasjonslogger direkte til OpenObserve via den nye
`Messngr.Logging.OpenObserveBackend`-modulen. Konfigurasjonen styres gjennom
miljøvariabler i `backend/config/dev.exs`, for eksempel:

```bash
OPENOBSERVE_ENABLED=true \
OPENOBSERVE_ENDPOINT=http://openobserve:5080 \
OPENOBSERVE_STREAM=backend
```

Metrikk-endepunktet (port 9568) og logger (OpenObserve) eksponeres kun i
utviklingsmiljøet som er startet via `docker compose up`.

### Tilpasninger

- Sett `PHX_LISTEN_IP` om du ønsker å binde serveren til en annen adresse.
- Legg til ekstra miljøvariabler i `docker-compose.yml` ved behov.

## Lokal kjøring uten Docker

Se mix-filene i de respektive appene for alias som `mix setup` og
`mix phx.server` dersom du vil kjøre miljøet uten containere.

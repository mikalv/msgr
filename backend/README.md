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

### Tilpasninger

- Sett `PHX_LISTEN_IP` om du ønsker å binde serveren til en annen adresse.
- Legg til ekstra miljøvariabler i `docker-compose.yml` ved behov.

## Lokal kjøring uten Docker

Se mix-filene i de respektive appene for alias som `mix setup` og
`mix phx.server` dersom du vil kjøre miljøet uten containere.

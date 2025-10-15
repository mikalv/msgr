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
- Sett `PROMETHEUS_ENABLED=false` dersom du vil skru av eksportøren i et
  begrenset miljø. Porten kan overstyres med `PROMETHEUS_PORT`.
- **Grafana** startes med en forhåndsprovisjonert Prometheus-datakilde og er
  tilgjengelig på `http://localhost:3000` (bruker/pass: `admin`/`admin`).
- **OpenObserve** håndterer loggdata på `http://localhost:5080`. Standardbrukeren
  er `root@example.com` med passord `Complexpass#123`.

Backenden publiserer applikasjonslogger via StoneMQ-topicen `observability/logs`
ved hjelp av `Messngr.Logging.OpenObserveBackend`. En dedikert konsument kan
lese denne strømmen og skrive til OpenObserve. HTTP-transporten er fortsatt
tilgjengelig for lokale tester, men du kan aktivere StoneMQ-transporten ved å
sette miljøvariabler i `backend/config/dev.exs`, for eksempel:

```bash
OPENOBSERVE_ENABLED=true \
OPENOBSERVE_TRANSPORT=stonemq \
OPENOBSERVE_QUEUE_TOPIC=observability/logs
```

Metrikk-endepunktet (port 9568) og logger (OpenObserve) eksponeres kun i
utviklingsmiljøet som er startet via `docker compose up`.

### Tilpasninger

- Sett `PHX_LISTEN_IP` om du ønsker å binde serveren til en annen adresse.
- Legg til ekstra miljøvariabler i `docker-compose.yml` ved behov.
- Kopier `.env.example` til `.env` for å toggle TLS/Noise og andre miljøverdier uten å endre koden.

### TLS/HTTPS-lytteren

Phoenix-endpointet kan starte en egen HTTPS-lytter når du vil teste TLS lokalt
eller i staging. Dette styres via miljøvariabler slik at du slipper å endre
`runtime.exs`:

- `MSGR_TLS_ENABLED`: Sett til `true` for å starte HTTPS-lytteren.
- `MSGR_TLS_CERT_PATH` / `MSGR_TLS_KEY_PATH`: Absolutte stier til sertifikat og
  privatnøkkel inni containeren.
- `MSGR_TLS_PORT`: Porten HTTPS-lytteren bruker (default `4443`).
- `MSGR_TLS_CACERT_PATH`: (valgfri) CA-bundle dersom du bruker egen CA.
- `MSGR_FORCE_SSL`: Sett til `true` dersom trafikk på HTTP-porten skal
  redirectes til HTTPS.
- `MSGR_FORCE_SSL_HSTS`: Aktiver HSTS når `MSGR_FORCE_SSL=true`.

Når TLS er deaktivert logges en advarsel dersom du forsøker å sette `MSGR_FORCE_SSL`
slik at feilkonfigurasjoner fanges tidlig.

## Media-signering

Alle opplastings- og nedlastings-URLer signeres med en hemmelig nøkkel slik at
ingen kan manipulere forespørsler til object storage. Sett
`MEDIA_SIGNING_SECRET` i miljøet før du starter backenden (Docker Compose gjør
det enkelt via `.env` eller direkte variabler). Hver installasjon bør bruke en
unik verdi – du kan generere en ved å kjøre

```bash
openssl rand -hex 32
```

I utviklings- og testmiljø faller backenden tilbake til en midlertidig
standardnøkkel dersom variabelen ikke er satt, men i staging/prod må den være
eksplisitt konfigurert. Når du oppretter mediaopplastinger kan du sende med en
checksum; den signeres nå sammen med URLen slik at klienter kan verifisere at
innholdet ikke er tuklet med før det vises.

## Media-retensjon

Backenden rydder nå jevnlig opp i opplastinger der `retention_expires_at` har
passert. En bakgrunnsprosess (`Messngr.Media.RetentionPruner`) kjører som del av
OTP-treet og sletter både database-rader og tilhørende objekter i storage.
Standardintervallet er hvert tiende minutt og prosessen tar maks 100 rader om
gangen for å unngå store batcher som kan påvirke IO.

Konfigurasjon kan overstyres via miljøvariabler:

- `MEDIA_RETENTION_SWEEP_ENABLED` (`true`/`false`) skrur jobben av/på.
- `MEDIA_RETENTION_SWEEP_INTERVAL_MS` setter intervallet i millisekunder (default
  600000).
- `MEDIA_RETENTION_SWEEP_BATCH_SIZE` bestemmer hvor mange opplastinger som
  behandles per kjøring (default 100).

Alle verdier kan også settes direkte i `config/config.exs` eller via
`runtime.exs` dersom du trenger forskjellige innstillinger per miljø.

## Noise-konfigurasjon

msgr-backenden har støtte for en Noise-basert transport som for tiden er
feature-togglet. Når transporten er deaktivert lastes ikke statiske nøkler og
ingen TCP-lytter startes. I produksjon anbefales det å hente nøkkelen fra en
Secrets Manager (AWS støttes per nå), mens utvikling har en ferdig initialisert
nøkkel slik at du kan komme i gang umiddelbart.

- `NOISE_TRANSPORT_ENABLED`: Sett til `true` for å slå på Noise-transporten.
  Default er `false` i alle miljøer slik at funksjonaliteten kan toggles når den
  er klar.
- `NOISE_TRANSPORT_PORT`: Overstyr porten Noise-serveren skal bruke. Default er
  `5443` slik at håndtrykket kjører på en egen port adskilt fra HTTPS API-et.

- `NOISE_STATIC_KEY`: Base64-kodet privatnøkkel. Dersom satt brukes denne
  verdien direkte.
- `NOISE_STATIC_KEY_SECRET_ID`: Navn/ARN i Secrets Manager. Når satt vil
  backenden forsøke å hente hemmeligheten via AWS API.
- `NOISE_STATIC_KEY_SECRET_FIELD`: (valgfri) JSON-felt i hemmeligheten som
  inneholder nøkkelen. Default er `"private"` i dev.
- `NOISE_STATIC_KEY_SECRET_REGION`: (valgfri) Overstyrer AWS-region for
  nøkkelhenting, ellers brukes `AWS_REGION`.
- `NOISE_STATIC_KEY_ROTATED_AT`: ISO8601-tidspunkt som beskriver når nøkkelen
  sist ble rotert. Brukes kun for dokumentasjon/logging.

Utviklingsmiljøet (`config/dev.exs`) definerer en default-nøkkel som brukes når
ingen av variablene over er satt. Du kan overstyre den ved å eksportere din egen
`NOISE_STATIC_KEY`. Husk samtidig å sette `NOISE_TRANSPORT_ENABLED=true` dersom
du skal teste Noise-håndtrykket lokalt.

### Klientnøkler for enheter

Statiske klientnøkler som registreres gjennom OTP/OIDC må nå være 32 eller 64
byte lange og leveres som URL-sikker base64 uten padding (hex støttes også og
konverteres automatisk). Backenden normaliserer nøklene, lagrer et SHA-256
fingeravtrykk og tar vare på attestasjonsmetadata slik at kompromitterte
enheter kan identifiseres og deaktiveres under alpha-testingen. Dersom du
videresender nøkler fra klienter må du oppgradere til det nye formatet før
registrering.

### Hente fra AWS Secrets Manager

Konfigurer følgende miljøvariabler i tillegg til `NOISE_STATIC_KEY_SECRET_ID`:

- `AWS_REGION`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- Eventuelt `AWS_SESSION_TOKEN` for midlertidige nøkler.

Secret-verdien må være en base64-kodet streng. Dersom du lagrer et JSON-objekt
kan du peke på feltet som inneholder nøkkelen ved å sette
`NOISE_STATIC_KEY_SECRET_FIELD`.

### Roter statisk nøkkel

Bruk mix-tasken `mix noise.rotate_static_key` for å generere nye nøkkelpar og
loggføre fingerprint:

```bash
cd backend
mix noise.rotate_static_key --print-private --json
```

Tasken skriver fingerprint og base64-kodede nøkler. Oppdater
`NOISE_STATIC_KEY` eller hemmeligheten i Secrets Manager med den nye private
nøkkelen. Sett `NOISE_STATIC_KEY_ROTATED_AT` til tidspunktet oppgitt av tasken
for å dokumentere rotasjonen.

## Lokal kjøring uten Docker

Se mix-filene i de respektive appene for alias som `mix setup` og
`mix phx.server` dersom du vil kjøre miljøet uten containere.

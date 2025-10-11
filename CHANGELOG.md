# Changelog

## Unreleased
- Replaced the Telegram/Matrix HTTP clients with queue-driven bridge facades for Telegram, Matrix, IRC, and XMPP plus a shared `ServiceBridge` helper and in-memory queue adapter tests.
- Introduced a queue behaviour contract to standardise `bridge/<service>/<action>` envelopes with trace IDs for all connectors.
- Updated bridge strategy, architecture, account linking, and platform research docs to focus on StoneMQ-backed daemons and MTProto-based Telegram support.
- Spun opp nytt `family_space`-bibliotek med generaliserte "spaces" for familier/bedrifter, delt kalender samt handleliste- og todo-funksjoner med REST-endepunkter, Ecto-migrasjoner og tester.
## [Unreleased]
### Added
- Konsolidert produktplan og forskningsoppsummering med fokus på chat-MVP, identitet og arkitektur.
- Ny domenemodell på backend for kontoer, profiler, samtaler og meldinger med REST API for chat.
- Sanntidsklar Flutter-chatopplevelse med ny `ChatPage`, timeline, og rik tekstkomponist.
- API-klient, view-model og tester for chatflyt i Flutter.
- CHANGELOG innført for å følge endringer.
- Widgettester for chat-komponisten for å sikre interaksjonene rundt sendeknappen.
- Dokumentert API-kontrakt for REST og WebSocket i `docs/api_contract.md`.
- Phoenix-basert samtale-kanal med PubSub-broadcast og Flutter-klient for sanntid.
- Passordløs autentisering med støtte for e-post, mobil og OIDC via `Auth`-kontekst og nye identitetsskjema.
- REST-endepunktene `/api/auth/challenge`, `/api/auth/verify` og `/api/auth/oidc` med JSON-svar og tester.
- OTP- og OIDC-dokumentasjon i `docs/api_contract.md` samt database-migrasjoner for identiteter og utfordringer.
- Flutter-støtte for OTP-flyt med `AuthChallenge`-modell, redux-tilstand og forbedret kodevisning.
- Docker-basert utviklingsmiljø for Elixir-backenden med Postgres og Phoenix-server.
- Konfigurerbar Flutter-backend gjennom `BackendEnvironment` med støtte for
  `--dart-define` og runtime-overstyringer samt oppdatert README for å beskrive
  bruken.
- Docker-image og Compose-tjeneste for StoneMQ slik at meldingskøen kan startes
  sammen med resten av utviklingsmiljøet.
- Prometheus-eksport fra backenden med ferdig Prometheus- og Grafana-tjenester i
  docker-compose.
- OpenObserve-loggflyt for Elixir-backenden med ny Logger-backend og tester.
- Flutter-loggklient som kan sende `package:logging`-poster til OpenObserve via
  `LoggingEnvironment` og en gjenbrukbar HTTP-klient.
- Familie- og space-funksjoner flyttet til eget `family_space`-bibliotek med kalender, handlelister og todo-støtte samt oppdatert API-dokumentasjon.

### Changed
- Backend-konfigurasjon forenklet og unødvendige apper fjernet fra releaseoppsett.
- HomePage viser nå ny chatopplevelse i stedet for gamle lister.
- Chat-opplevelsen i Flutter har fått en modernisert visuell profil med felles tema, oppgradert tidslinje og raffinert komponist.
- ChatViewModel benytter nå sanntidsstrømmer og WebSocket-sending med HTTP-fallback.
- Innloggingsopplevelsen i Flutter er redesignet med glass-effekt, segmentert kanalvalg og OIDC-knapp.
- `RegistrationService` bruker nå de nye auth-endepunktene og returnerer strømlinjeformede brukersvar.

### Fixed
- `mix` og Flutter-konfigurasjon oppryddet for å matche den nye strukturen.

# Changelog

## Unreleased
- Flutter-klienten sender nå enhet- og app-informasjon til auth-backenden ved
  oppstart via nytt device-context-bootstrapp, og reetablerer brukerøkter når
  JWT-er har utløpt.
- Auth-provider-backenden tar imot oppdatert enhetskontekst, lagrer app-metadata
  og utsteder nye refresh-tokens, med tilhørende tester for API og hjelpere.
- Startet migreringen til ny Flutter-arkitektur med modulært `app/bootstrap`,
  ryddigere `main.dart` og første test for loggoppsettet.
- Lagt ved `IMPROVE_ARCHITECTURE.md` med veikart for å modernisere Flutter-klientens struktur,
  state-håndtering og moduloppdeling.
- Added initial WebRTC signalling stack with in-memory call registry, Phoenix `rtc:*` channel, tests, documentation, and a dockerised coturn service for TURN/STUN.
- Tightened direct-call support by capping participants to vert + én, utvidet testdekning og dokumentasjon av Flutter-klientplanen.
- Introduced conversation structure types (familie, bedrift, vennegjeng, prosjekt)
  with private/team visibility, backend validation, and updated Flutter UI/API for
  creating skjulte kanaler og grupper.
- Utvidet samtalekonseptet med støtte for `group`- og `channel`-typer i Elixir-
  backenden, nye API-endepunkter og validering av temaer.
- Lagt til kontaktskjema, migrasjoner og REST-endepunkter for import og
  identitetsoppslag samt Flutter-klienter for begge operasjoner.
- Oppdatert Flutter-chatmodeller, API-klient, view-model og opprettelsesdialog
  for å forstå kanal- og gruppesamtaler og tilgjengeliggjort enhetstester for
  parsing av tråder.
- Utvidet `family_space`-biblioteket med delt notatfunksjon, REST-endepunkter og migrasjon for `space_notes`.
- Replaced the Telegram/Matrix HTTP clients with queue-driven bridge facades for Telegram, Matrix, IRC, and XMPP plus a shared `ServiceBridge` helper and in-memory queue adapter tests.
- Introduced a queue behaviour contract to standardise `bridge/<service>/<action>` envelopes with trace IDs for all connectors.
- Updated bridge strategy, architecture, account linking, and platform research docs to focus on StoneMQ-backed daemons and MTProto-based Telegram support.
- Spun opp nytt `family_space`-bibliotek med generaliserte "spaces" for familier/bedrifter, delt kalender samt handleliste- og todo-funksjoner med REST-endepunkter, Ecto-migrasjoner og tester.
- Begynt å implementere lokal SQLite-cache for meldinger og kontakter i Flutter-klienten med nye DAO-er, migrasjoner og tester.
- Added audio message support across the shared msgr domain, Flutter chat model, and parser including waveform metadata handling.
- Built a MinIO-ready media upload API on the Elixir backend with audio/video attachment workflows, storage configuration, and test coverage.
- Designed a reusable `MsgrSnackBar` UI component with typed snackbar messages, intent-aware theming, and widget/unit tests.
- Replaced the Telegram/Matrix HTTP clients with queue-driven bridge facades for Telegram, Matrix, IRC, and XMPP plus a shared `ServiceBridge` helper and in-memory queue adapter tests.
- Introduced a queue behaviour contract to standardise `bridge/<service>/<action>` envelopes with trace IDs for all connectors.
- Updated bridge strategy, architecture, account linking, and platform research docs to focus on StoneMQ-backed daemons and MTProto-based Telegram support.
- Implemented a multi-tenant identity provider (IDP) umbrella app with tenant schemas, OIDC/OAuth service-provider support, Guardian-based token issuance, Phoenix session helpers, tests, and documentation (`docs/idp.md`).
- Added a dedicated `llm_gateway` umbrella-app that unifies communication with OpenAI, Azure OpenAI, Google Vertex and OpenAI-kompatible modeller, including konfigurerbar nøkkeloppløsning for system- og team-nivå og omfattende tester/dokumentasjon.
- Introduced the `Messngr.AI` context, REST API endpoints for chat completions, summaries and conversation replies, plus controller/views, configuration and tests wired to the shared `llm_gateway` service.
- Enriched the shared msgr message domain with bubble styling, curated theme palettes, and runtime theme switching helpers for every message variant.
- Redesignet Flutter-hjemmeskjermen med et responsivt oppsett for mobil, nettbrett og desktop, komplett med gradient-sidefelt, innboks-panel og handlingslinje.
- La til widgettester for brytepunktene og dokumenterte strukturen i `docs/frontend_responsive.md`.
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
- `msgr_messages`-bibliotek med tekst, markdown, kode og systemmeldinger, parser og omfattende enhetstester for gjenbruk i klientene.
- `msgr_messages`-biblioteket utvidet med bilde-, video- og lokasjonsmeldinger, felles temadefinisjon og parserstøtte med nye enhetstester.
- AuthShell-layout og delte inputdekorasjoner for autentiseringsskjermene med tilhørende widgettest.
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
- Flutter-skjermene for innlogging, registrering og kodeverifisering har fått en helhetlig profesjonell stil med gradientbakgrunner, bullet-highlights og oppdatert PIN-inntasting.
- `RegistrationService` bruker nå de nye auth-endepunktene og returnerer strømlinjeformede brukersvar.
- `ChatMessage`-modellen i Flutter arver nå `MsgrTextMessage` og gjenbruker de delte msgr-modellene.
- `ChatMessage` JSON-serialisering inkluderer nå delt tema-informasjon slik at klienter kan bytte utseende konsistent.

### Fixed
- `mix` og Flutter-konfigurasjon oppryddet for å matche den nye strukturen.

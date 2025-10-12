# Changelog

## Unreleased
- Drafted a bridge authentication and client experience plan covering OAuth/OIDC flows, UI wizard design, and future IP egress mitigation options.
- Documented Snapchat web protocol capture details in `reverse/docs/snapchat.protocol.md` and outlined bridge implications.
- Added a Snapchat service bridge facade with session refresh, messaging, and sync helpers plus test coverage.
- Expanded the Snapchat protocol notes with techniques for extracting bundled protobuf descriptors from the web client so the
  bridge can reverse engineer message schemas.
- Introduced a Postgres-backed share link service with capability profiles,
  msgr:// deep-link generation, and public URL helpers so bridges can share
  media, locations, and invites with text-only networks while enforcing
  expiry/view limits.
- Added bridge contact profiles, match-key storage, and profile links so Msgr
  can aggregate the same person across bridge rosters and native Msgr contacts;
  includes new Postgres tables, context helpers, and regression tests for the
  matching workflow.
- Added a Postgres-backed `Messngr.Bridges` context with new `bridge_accounts`,
  `bridge_contacts`, and `bridge_channels` tables so bridge daemons can persist
  capabilities, session material, contact rosters, and channel memberships per
  account.
- Extended the Telegram and Signal bridge daemons to advertise capability maps
  and roster/channel snapshots during the link handshake and wired the Elixir
  connectors to sync those payloads into the new bridge data store with unit
  coverage.
- Extended the Telegram bridge daemon with outbound edit/delete handlers and richer inbound
  normalisation so replies, entities, and media descriptors flow through to Msgr alongside
  acknowledgements.
- Added attachment upload support to the Signal REST client, including multipart handling for
  inline data, pre-uploaded attachment IDs, and regression tests covering both code paths.
- Implemented read acknowledgement tracking in the Telegram bridge so Telethon clients send
  `send_read_acknowledge` calls when Msgr emits `ack_update`, and expanded unit tests to cover
  stored contexts and unknown-update behaviour.
- Added a Signal REST client built on `signal-cli-rest-api`, complete with polling, outbound send,
  and acknowledgement tests plus documentation updates for the new adapter.
- Scaffolded a Snapchat bridge package with session helpers, a queue-facing daemon skeleton, and
  regression tests that record unimplemented invocations pending real API access.
- Updated bridge documentation to reflect Telegram acknowledgement support, the Signal REST client,
  and the Snapchat skeleton status.
- Implemented a Matrix bridge daemon with disk-backed session management, queue handlers for
  linking, outbound messaging, and update acknowledgements plus fake Matrix client support so the
  SDK can talk to homeservers once real protocol adapters land.
- Added Matrix bridge unit tests that exercise account linking, outbound message relays, inbound
  update publication, and acknowledgement tracking through the StoneMQ client transport.
- Documented the current bridge implementation gaps in `docs/bridge_status.md` so we know which
  services still need real protocol clients before the deployments can run.
- Implemented a Signal bridge daemon skeleton with device-link queue handlers, disk-backed session
  management, and unit tests covering account linking, outbound messaging, and acknowledgement
  workflows to mirror the WhatsApp/Telegram bridges.
- Documented Signal support across the multi-bridge blueprint, architecture overview, and
  integration kick-off notes, expanding the `msgr://` scheme, service action map, and lifecycle
  guidance for device linking and sealed-sender handling.
- Introduced a WhatsApp bridge daemon skeleton with client-protocol abstractions, disk-backed
  session management, StoneMQ queue wiring, and unit tests covering QR pairing flows, outbound
  messaging, and acknowledgement handling.
- Documented WhatsApp support in the multi-bridge blueprint with queue contracts, lifecycle notes,
  URL mappings, and failure-handling guidance so deployments can plan for multi-device pairing.
- Implemented the first Telegram MTProto bridge daemon with a Telethon-compatible
  client factory, disk-backed session store, StoneMQ queue wiring, and tests for
  linking flows, outbound messaging, and update acknowledgements.
- Extended the Python StoneMQ client with request-handler support so bridge
  daemons can respond to `link_account` RPCs, including new unit tests covering
  transport behaviour.
- Expanded the bridge blueprint to cover XMPP and Telegram alongside Matrix/IRC, detailing
  queue contracts, lifecycle expectations, and the `msgr://` scheme for new resources, plus updated
  architecture notes for multi-service action maps and Telegram client emulation guidance.
- Added instance-routing regression tests for the XMPP and Telegram connector facades so `send_stanza`
  and `send_message` can target sharded bridge deployments while preserving default metadata.
- Implemented instance-aware bridge routing so Msgr can target specific Matrix/IRC shards via `bridge/<service>/<bridge_id>/<action>` topics, updating the Elixir connector facade, Go/Python SDKs, docs, and tests to respect connection caps per daemon deployment.
- Documented the initial Matrix and IRC bridge blueprint, covering MVP
  transport goals, queue mappings, and an `msgr://` deep-linking scheme for
  channels, identities, and messages.
- Added MVP-plan for chat-klient i `docs/chat_client_mvp_plan.md`.
- Added per-recipient message delivery receipts with database schema, REST and
  WebSocket acknowledgement flows, status propagation to messages, and test
  coverage for delivery/read guarantees.
- Added read receipt privacy controls so accounts and team conversations can
  disable read acknowledgements; the backend now skips read broadcasts/status
  escalations when disabled, exposes the settings via conversation payloads,
  and covers the behaviour with new regression tests.
- Added REST toggles for read receipt preferences on accounts and conversations,
  exposing the settings in account payloads and adding controller coverage so
  privacy choices can be updated after onboarding.
- Added Markdown-lenkeformatering i chat-komponistens verktøylinje og et drahåndtak for høydejustering med nye widgettester og oppdatert paritetsplan.
- Hardened chat composer phase A/B work: added autosave snapshot persistence with background sync manager, pessimistic send/queue states with retry UI, refreshed accessibility (focus order, semantics) and documented design & research updates.
- Split the Flutter chat composer into a modular library with dedicated files
  for the widget, toolbar, palettes, controller, models and voice helpers so it
  is easier to navigate and maintain.
- Added formatting toolbar, mention-autocomplete palette and mention tracking to
  the Flutter chat composer, including controller/result updates and new widget
  tests for the rich text actions.
- Routed backend logger output through StoneMQ envelopes so `Messngr.Logging.OpenObserveBackend` can forward entries to
  OpenObserve via the `observability/logs` topic, including StoneMQ transport configuration and tests.
- Added StoneMQ-aware OpenObserve loggers to the Go and Python bridge SDKs so daemons can emit envelopes compatible with the
  backend pipeline, with unit test coverage.
- Finalised the StoneMQ bridge envelope contract with typed Elixir helpers,
  updated ServiceBridge publishing/request flows, and added envelope test
  coverage.
- Bootstrapped cross-language bridge SDK skeletons (Go/Python) with StoneMQ
  queue topics, envelope parsing, telemetry hooks, credential bootstrapper
  stubs, and unit tests.
- Added bridge integration execution plan documenting RE rounds and candidate
  upstream projects for Discord, Slack, Snapchat and other chat networks.
- Added REST-støtte for kontaktimport og match i backenden med nye
  controller-tester, oppdatert API-kontrakt og Flutter `libmsgr`
  klientimplementasjon for å lagre kontakter og slå opp kjente venner.
- Documented the `libmsgr` API surface, added a dedicated CLI entry point for
  the registration flow (`tool/msgr_cli.dart`), and updated the integration test
  suite to use the new command for provisioning accounts.
- Added multi-identity account linking so `Accounts.ensure_identity/1` can attach
  new email/phone/OIDC credentials to an existing account via `account_id`, with
  safeguards against cross-account hijacking, refreshed docs and regression
  tests for linking flows.
- Added Snapchat Camera Kit capture pipeline to the Flutter chat composer with
  environment-based configuration, Android/iOS method-channel bridges,
  fallbacks for unsupported platforms, native dependency wiring, unit tests and
  documentation describing setup requirements.
- Enforced Noise-handshake attestasjonskrav for OTP (`/api/auth/verify`) med
  Telemetry-instrumentering, fullstack tester (unit/integration) for happy-path,
  feilscenarier (feil signatur, utløpt session, rekey) i både `msgr` og
  `auth_provider`, ny ConnCase-test for API, runtime feature-flag med
  `mix rollout.noise_handshake`, og dokumentasjon i `docs/noise_handshake_rollout.md`
  + oppdatert API-kontrakt så klienter vet hvordan `Authorization: Noise <token>`
  skal brukes.
- Added docker-compose backed integration test suite that boots the backend,
  exercises the Dart CLI flow for registration/login/team creation and verifies
  message send/receive over the public APIs via pytest.
- Exposed an opt-in `MSGR_WEB_LEGACY_ACTOR_HEADERS` runtime flag so integration
  tests can rely on legacy headers while Noise authentication is still rolling
  out.
- Replaced header-based actor resolution with a shared Noise session plug that
  validates tokens against the registry, assigns account/profile/device for
  REST and WebSocket contexts, adds feature-toggled legacy fallback, updates
  channel/controller flows to rely on socket assigns, and introduces Noise
  session fixtures/tests for both plugs and sockets.
- Expanded Noise authentication coverage with dedicated tests for the shared
  plug (headers, session persistence, feature flags, device edge cases) and the
  session store helpers, improving confidence in Noise token validation.
- Added GitHub Actions deploy workflow that runs on release tags to build the Elixir release, ship it via rsync to `msgr.no`, and restart the systemd service on Ubuntu 22.04 runners.
- Added Noise transport session and registry modules with NX/IK/XX handshake
  support, session-token generation and registry TTL management, plus
  integration/property tests for handshake, fallback and rekey flows.
- Startet Slack API-umbrellaappen med reelle `conversations.*`, `chat.*`, `users.*` og `reactions.*` endepunktimplementasjoner, Slack-ID/timestamp-adaptere, header-basert autentiseringsplugg og tilhørende controller-tester.
- Implementerte `conversations.mark` for Slack API-et slik at lesestatus lagres, og la til tester som dekker lykkestien og ugyldig timestamp-feil.
- Lagt til plan i `docs/umbrella_slack_compat_plan.md` for Slack-kompatibel umbrella-plattform og prioritering av Telegram og Discord-integrasjoner.
- Utvidet roadmap-dokumentet for message composer-paritet i
  `docs/message_composer_parity_plan.md` med detaljerte faser,
  kickoff-sjekkliste og risikovurdering.
- Added account device management with migrations, CRUD helpers, Noise key
  attestation storage and auth flow integration so OTP/OIDC logins register
  and activate devices, including ExUnit coverage.
- Documented Noise handshake expectations with new server-key endpoint contract, configured backend runtime to load static Noise keys from env/Secrets Manager, added rotation mix task with tests, and updated README guidance.
- Added a feature toggle and dedicated port configuration for the Noise transport so static keys only load when explicitly enabled.
- Utvidet mediasystemet med nye skjema-felter (dimensjoner, SHA-256, retention),
  nye opplastingskategorier (image, file, voice, thumbnail) og presignerte
  URL-instruksjoner for forhåndsgenererte thumbnails.
- Messngr.Chat validerer nå mediepayloader (captions, thumbnails, waveform),
  normaliserer metadata og eksponerer `media`-feltet i `MessageJSON` med nye
  ExUnit-tester for både chat- og mediastrømmen.
- Flutter-klienten har fått ny opplastingsflyt (drag & drop, kamera, voice),
  forhåndsvisninger i `ChatBubble`, helper for medieopplasting og oppdaterte
  widget- og modelltester.
- Reintroduced the chat backlog broadcast helper so `message:sync` emits shared
  cursor pages over PubSub again, with backend regression tests.
- Added configurable TTL cleanup for conversation watcher lists so inactive
  viewers fall out of the PubSub feed automatically, with backend tests and
  refreshed documentation.
- Dokumentert Taskku-produktivitetsappen som referanse for bedriftsmodus med ny
  forskningsfil som kobler UI-mønstre til eksisterende API-er og bridge-strategi,
  og oppdatert med plan for å holde produktivitetsmoduler adskilt fra kjernchat i
  både UI og backend.
- Secured media uploads with mandatory server-side encryption headers in presigned instructions, configurable SSE/KMS settings, tests, and updated API documentation.
- Enhanced media upload pipeline with voice/file/thumbnail kinds, width/height/checksum metadata, retention TTLs and presigned URL helpers in the Elixir backend (new migration, config, storage helpers and tests).
- Normalised chat media payloads (captions, thumbnails, waveform) with updated JSON views, message validations and API contract documentation.
- Reworked Flutter chat media flow with composer previews, upload helpers, ChatBubble media rendering and refreshed unit/widget tests.
- Hooked Flutter chat realtime flows into typing/read/reaction/pin events with
  a richer `ChatSocket`, notifier-aware `ChatViewModel`, pinned/thread UI
  toggles, and new integration/unit tests for realtime behaviour.
- Added message reactions, threaded replies, pinned state, and read tracking to the
  chat backend with PubSub broadcasts, upgraded Phoenix channel presence/typing
  flow, and Flutter notifiers/widgets for typing indicators, reaction aggregates,
  and pinned banners with accompanying tests.
- Implementerte cursor-baserte historikk-APIer for meldinger og samtaler med
  PubSub-backlog (`message:sync`) og watcher-strømmer (`conversation:watch`/`unwatch`).
- Designet et modulært Flutter chat-UI-kit (kanalliste, trådvisning, reaksjoner, presence, tilkoblingsbanner) og integrerte det i `ChatPage` og en ny `ChannelListPage`-demo.
- Utvidet `ChatComposer` med emoji-velger, slash-kommandoer, filvedlegg, simulert taleopptak og forbedret utkast-/feilhåndtering samt nye widgettester og demo-widget.
- Forsterket chat-komponisten med pålitelig tekstutsending, per-tråd-utkast og nye view-model-tester for sendefeil og kladd-restaurering.
- Implementerte hurtigbuffer for samtaler og meldinger med Hive/Sembast, offline statusbanner og integrasjonstester for fallback i `ChatViewModel`.
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
- La til Cupertino-inspirerte kontaktvisninger i Flutter-klienten (liste, detalj og redigering),
  systemkontakt-import via `flutter_contacts` og nye widgettester for flyten.
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
- Dokumentasjon av ulike driftsmodeller for bridge-daemons (administrert, kundeoperert og hybrid) i `docs/bridge_hosting_options.md`, nå utvidet med research-notater fra Beepers Bridge Manager.

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

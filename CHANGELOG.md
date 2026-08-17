# Changelog

## Unreleased

### Docs — engineering documentation refresh
- Added `docs/media_virus_scan.md` runbook for team ClamAV scan/quarantine (API, env, pitfalls)
- Updated `docs/CODEBASE_ANALYSIS.md` for delivered E2EE 1:1, ClamAV, CI quality/coverage/integration, and security review status
- Refreshed `docs/rtc.md` for shipped Flutter WebRTC client + TURN credentials endpoint
- Linked media/E2EE/RTC docs from `README.md` and `docs/backend_setup.md`

### Added — E2EE end-to-end verification
- ExUnit wire-flow suite for personal-mode encrypted relay (`init` → `init_ack` → `msg`) asserting empty `body` and no plaintext leakage in stored/listed payloads
- Dart HTTP E2E (`libmsgr_core` + `scripts/run_e2ee_e2e.sh`) that runs two real `E2eeService` clients against Phoenix via bot-token auth and decrypts across the wire
- Encrypted messages now force `body` to `""` server-side so clients cannot persist plaintext by accident

## [0.8.0] — 2026-03-26 to 2026-03-27

### Added — App Platform & Marketplace (#96, #97, #98)
- **App marketplace** in Team Settings > Apps: browse, search, category filter, install with scope review + config form + channel binding
- **Bot token management**: list/create/revoke tokens via API and UI
- **Webhook dispatch**: HMAC-SHA256 signed outgoing webhooks with exponential backoff retry (5 attempts)
- **Channel app config**: per-channel JSONB metadata for app-specific settings
- App directory endpoint with search and category filter
- Seed apps: GitHub, Calendar/JMAP, Jira, RSS, Sentry, Grafana
- Channel Settings > Apps tab for per-channel app configuration

### Added — UI/UX Features
- **Message hover toolbar** (#134): floating action bar on hover with React, Reply, Thread, Pin, More buttons
- **Reply-to messages** (#147): quote block with accent border, reply mode in composer, Esc to cancel
- **Pinned messages** (#148): pin/unpin via context menu, pin icon on messages, dropdown panel in channel header with badge count
- **Profile hover cards** (#131): hover 400ms over sender name/avatar shows mini card with Message/Profile buttons
- **Favorite channels/DMs** (#125): star via context menu, dedicated "Starred" section at top of sidebar
- **Last message preview** (#145): sidebar shows sender + text preview below channel/DM name
- **6 color themes** (#149): Neutral, Teal, Indigo, Rose, Amber, Emerald — each with light/dark/system mode
- **Location sharing** (#151): GPS + reverse geocoding, OpenStreetMap map cards, location button in composer
- **Contact sharing** (#151): native contact picker, contact cards with tap-to-call/email
- **Leave channel / close DM**: context menu actions, self-DM ("Notes to self") cannot be closed
- **macOS dock badge**: unread count on dock icon + bounce on new messages

### Added — Team Admin (#129)
- Team admin settings panel with 3 tabs: Overview, Members, Invites
- Edit team name (admin/owner only)
- Member list with role badges, promote/demote/remove (owner)
- Invite link management: list, create, copy URL, revoke

### Added — Bot Improvements (#135)
- Bot handles `new:thread_reply` WebSocket events (was only listening to `new:message`)
- Bot replies in threads via `sendThreadReply` (not to channel)
- Bot requires @mention in channels, always replies in threads
- Bot can join teams via `--invite` flag (URL or raw code)
- Thread composer uses full ChatComposer with @mention popup

### Fixed
- **Invite links for existing users**: web flow now works when already logged in (auth state race fix)
- **Profile setup after invite-join**: `needsProfileSetupProvider` triggers setup for new team joins
- **REST thread broadcast**: thread replies via REST API now broadcast as `new:thread_reply` (was `new:message`)
- **Clipboard paste on macOS**: added TIFF format support for screenshots, fixed paste race condition
- **Image-only messages**: no longer show `[vedlegg]` text, empty content hidden gracefully
- **Webhook dialog Esc crash**: removed manual TextEditingController dispose (GC handles it)
- **Selected channel readability**: text now always white + bold on active background
- Webhook template engine: Liquid preset rendering for GitHub, GitLab, Sentry, Grafana

### Infrastructure
- 14 bridge issues created: IRC, XMPP, Matrix, Slack, Discord, Messenger, WhatsApp, Signal, Telegram, iMessage, Google Chat, MS Teams, LinkedIn, Email
- Rebrand decision: Msgr → Relay (relay.dm) — issue #166 tracks phased rollout
- Issues created: Linux build (#164), App Store distribution (#165), invite landing page (#163), developer portal (#182), activity feed (#181)

---

## [0.7.0] — 2026-03-25 to 2026-03-26

### Added — Webhook Templates (#159)
- Liquid template engine with presets: GitHub, GitLab, Sentry, Grafana, Generic
- Webhook creation dialog with preset dropdown
- Edit template dialog with monospace Liquid syntax editor
- Webhook cards show preset badge and custom template indicator

### Added — Slash Commands (#92)
- Built-in commands: /poll, /remind, /topic, /who, /invite, /note
- /remind integrates with ReminderScheduler (30s check interval, delivers to self-DM + push)
- /note sends to self-DM channel
- /poll with emoji voting
- Command execution via REST and WebSocket

### Added — Other
- Text selection in messages (#162)
- Bot auto-reconnect with exponential backoff on server restarts
- Request logger with IP + user ID
- Rename: Slack* → Msgr* classes (#136)
- DM channel names show person names instead of hash slugs

---

## [0.6.0] — 2026-03-25

### Added
- Incoming webhooks (#119): Slack-compatible POST /api/hooks/:token, bot profiles
- Channel member management (#120): add/remove members, channel-specific member panel
- Private channels (#116): filtered channel listing, lock icon in sidebar
- URI scheme deep links (#124): msgr://team/channel, app_links package
- Web Push notifications: VAPID keys, push_sw.js service worker, subscription flow
- Web client loading screen with dark background + spinner
- Local CanvasKit bundling (no gstatic.com CDN dependency)
- Profile setup auto-dialog when joining team with empty display_name

### Fixed — WebSocket Stability
- **Root cause**: duplicate `channel "channel:*"` handler in UserSocket — old ConversationChannel was intercepting all channel topics, breaking joins and preventing push dispatch
- Removed ConversationChannel from socket routing; ChatChannel is sole handler
- Added `message:create` alias in ChatChannel (Flutter sends this, server had `new:message`)
- **Reconnect strategy rewrite**: never disconnect/reconnect manually. phoenix_socket handles auto-reconnect with exponential backoff. Creating new sockets on disconnect caused infinite loop.
- Periodic JWT refresh every 10 min prevents token expiry during long sessions

### Fixed — Push Notifications
- Push dispatch now runs from WebSocket path (was only REST before)
- VAPID JWT signing fixed (JOSE.JWK.from_map with JWK JSON format)
- Web Push sends to WNS/FCM endpoints (expired subscriptions auto-cleaned)

### Fixed — Other
- DM creation: filter out account-level profile IDs (use tenant profiles only)
- Message edit crash: DateTime microseconds truncated for :utc_datetime schema
- display_name not required at account creation (fallback to full email)
- ChannelMembership.join uses on_conflict: :nothing (idempotent)

## [0.5.0] — 2026-03-23

### Added — Team Invitations (#117)
- Link-based team invitations: any member can generate a shareable invite URL
- Invite links expire after 7 days, can be revoked by creator/admin
- Backend: `invite_links` table, InviteLink schema, create/list/revoke endpoints
- Backend: public `POST /api/invite/:code` endpoint for redeeming invites
- Flutter: "Invite people" button in sidebar generates link + copy-to-clipboard dialog
- Flutter web: `/invite/:code` URL handling — auto-redeems after login

### Fixed — Web Client
- Remove `dart:io` imports crashing Flutter web (realtime_provider, notification_provider, app_shell, desktop_notification_service)
- Fix Phoenix `check_origin` rejecting WebSocket from web client
- Conditional imports for desktop notification service (stub on web, osascript on macOS)

## [0.4.0] — 2026-03-23

### Added — Push Notifications
- APNS push notification backend with JWT ES256 auth via Finch HTTP/2
- Device token registration endpoint (POST /api/push/register)
- Push dispatcher: async notify channel members on new message
- macOS: native AppDelegate requests notification permission + registers token
- iOS: native AppDelegate with APNS token registration
- Push entitlements for both macOS and iOS (aps-environment, app groups)
- Token cached to file for cross-native/Flutter bridge

### Added — iOS App
- IOSApp entry point using AppShell/SimpleChatContent (same as desktop)
- Separate from desktop entry — no window_manager dependency
- iOS deployment target bumped to 16.0
- Ad Hoc and TestFlight distribution support

### Added — i18n
- Centralized `S` strings class with English (default) + Norwegian
- All hardcoded UI strings replaced with `S.xxx` across 6 files
- Locale switchable via `S.setLocale('en')`

### Added — Infrastructure
- Prism search engine running as systemd service (auto-start)
- Kåre bot deployed as systemd service with auto-reconnect
- PostgreSQL ILIKE search fallback while Prism text-field bug is open
- Auto-run ALL Ecto migrations on startup (both standard and tenant)

### Added — Features
- Avatar upload dialog: file picker, URL fetch, clipboard paste
- Bot auto-refreshes JWT token on 401 (no more silent death)

### Fixed
- Bundle ID renamed from dev.meeh.messngr to no.msgr.app (iOS, macOS, Android)
- WebSocket channel join REFUSED — ensure team_slug always set before join
- Commands endpoint returns empty list instead of 500 (missing slash_commands table)
- SnapCameraKit references removed from iOS AppDelegate (not installed)
- Removed unused submodules (async_redux, wire-server)
- APNS key mount fixed (was directory, now file)
- PEM key parsing fixed (PKCS#8 PrivateKeyInfo, not ECPrivateKey)

---

## [0.3.0] — 2026-03-22

### Added — UI Polish
- MsgrTheme system with semantic color tokens, dimensions, and InheritedWidget
- ProfileAvatar widget: Gravatar + letter fallback + online indicator
- Flat Slack-style composer (replaced rounded bubble design)
- ChannelHeader with topic display and action icons
- Sidebar: 1px border, accent-blue selection, content area contrast, profile footer with avatar
- DM list items with mini ProfileAvatars
- Syntax highlighting in code blocks (Monokai theme via flutter_highlight)
- `(redigert)` indicator on edited messages

### Added — Messaging
- Message editing: arrow-up shortcut + context menu, edit banner, Escape to cancel
- Message delete: soft delete with deleted_at, real-time removal via channel broadcast
- Optimistic media upload: images/files show immediately with spinner overlay
- Shift+Enter for newline, Enter to send (Slack-style)
- Typing indicator: REST endpoint for bots, event matching for typing_started/stopped

### Added — Auth & OTP
- SMTP email OTP via mail.meeh.dev with STARTTLS
- BulkSMS phone OTP via eAPI (simple HTTP GET)
- Bot-token auth endpoint (pre-shared secret, no OTP needed)
- debug_code removed entirely from API protocol and Flutter client

### Added — Search
- Prism 0.6.7 hybrid search engine installed on server
- Messages collection schema with full-text indexing
- Teams.Search module: async indexing on message send
- GET /api/teams/:slug/search endpoint
- Flutter search dialog with debounced results (search icon in header)
- Batch-indexed 119 existing messages

### Added — Infrastructure
- MinIO bucket auto-creation via minio/mc init container
- Auto tenant migrations on backend startup (Teams.Tenancy.migrate_all_tenants)
- Persistent unread counts with server-side read cursors
- GET /api/teams/:slug/unread_counts endpoint

### Fixed — Real-time Architecture (major overhaul)
- Deleted duplicate websocket_provider.dart (old system)
- Fixed WebSocket provider Riverpod rebuild race condition (ref.watch → ref.listen)
- Fixed channel join "forbidden" — ConversationChannel now authorizes Teams membership
- Fixed event name mismatch (client sent new:message, server expected message:create)
- Fixed channel push "succeeded with error" — client now checks reply for errors
- Added Teams-context handle_in("message:create") with proper broadcast
- Backend broadcasts to team:{slug} topic for sidebar unread counts
- Completed conversation: → channel: topic migration
- JWT token refresh before WebSocket reconnect (prevents 401 storm)
- Fixed 401 stacktrace spam (double respond_unauthorized in session plug)
- Fallback polling checks auth state and uses 15s interval

### Fixed — MinIO
- Renamed msgr_minio → msgr-minio (underscores invalid per RFC 952)
- Fixed ensure_bucket! with explicit force_path_style config
- Added :ssl to extra_applications for SMTP STARTTLS

### Changed
- Split simple_chat_content.dart (1973 lines) into 8 part files
- Removed unused business/personal app skeletons
- Backend avatar_url field added to profiles with API serialization

### Closed Issues
- #107 SMS verification (BulkSMS implemented)
- #109 S3 storage with presigned URLs
- #71 Backend Prism search integration
- #81 Flutter Search UI
- #112 Message delete
- #113 JWT token refresh (already implemented)
- #114 Unread counts

---

## [0.2.0] — 2026-03-21

### Added — Backend
- Multi-tenant PostgreSQL with tenant schemas per team
- JWT tokens (access 15min + refresh 30 days) via AuthProvider.Guardian
- REST API: teams, channels, messages, reactions, threads, profiles, media, DMs
- Phoenix Channels WebSocket: real-time messages, typing, presence
- Cursor-based pagination (before/after/around)
- App Platform Phase 1-3: executor framework, /poll /remind /topic, LLM executor with GitHub tools
- Channel member invites, presigned media URLs, thread reply count
- Room → Channel atomic rename (81 files)

### Added — Flutter (macOS)
- Slack/Discord hybrid 3-column layout
- Rich composer: markdown, emoji, voice, attachments, @mentions, slash commands
- Message rendering: grouping, markdown, timestamps, hover, reactions, threads
- Quick switcher (Cmd+K), native macOS menus, keyboard shortcuts, dock badge
- Profile cards, member panel, context menus, desktop notifications
- File sharing: upload, inline images, file cards
- JWT auth with auto-refresh, persistent login, sticky view, window persistence
- WebSocket real-time with polling fallback, delivery states, reconnection banner

### Added — Bot / LLM
- Kåre: LLM-powered hippie chatbot (qwen3.5-abliterated-35b)
- llm_agent package (pure Dart, headless)

### Added — Architecture
- libmsgr: pure Dart client library (zero Flutter deps)
- Identity URI: msgr://user@domain/resource, æ.me vanity URL
- App Platform design (7 phases), Rust NOISE gateway (future E2EE)

### Added — Infrastructure
- Docker Compose stack, multi-stage Dockerfiles
- Live on dev.msgr.no with wildcard TLS via proxyengine

### Fixed
- Circular deps between umbrella apps
- WebSocket tenant profile resolution
- Message content JSONB, deduplication, display name fallback
- @mention overlay positioning and click handling
- JWT enforcement, Docker port conflicts

---

## Unreleased (pre-0.2.0 history)

### Architecture checklist

- Added delivery status tracking for messages (pending/sending/delivered/failed),
  persisted in the local database with migration, websocket callbacks, and
  repository notifications so UIs can show sending/failed indicators.
- Modellert utvidede profilpreferanser (tema, varsel- og sikkerhetspolicyer) på
  Flutter, eksponerte `ProfileApi` for CRUD/bytte, la til modus-veksler med
  banner/inbox-filtre samt dokumentasjon av scenarier i `docs/profile_modes.md`.
- Etablerte per-profil nøkkellager (`profile_keys`) og backup-koder med
  `Messngr.Accounts.KeyStore`, inkludert generering/innløsningstester og klient-
  snapshot fingerprinting.
- Registrerte push-tokens i `device_push_tokens` og introduserte
  `Messngr.Notifications.PushDispatcher` med modus/quiet-hours-policy samt
  Flutter-støtte for å sende `clientState` og `encryption` sammen med media.
- Utvidet media-opplasting til å returnere `encryption`-placeholders og
  `clientState`, synket Flutter-uploader og dokumenterte flyten i
  `architecture.md`.
- [x] TLS kan toggles via miljøvariablene `MSGR_TLS_*` uten kodeendringer.
- [x] Noise-transport og handshake styres av `NOISE_*`-variabler og `libmsgr_core`.
- [x] Kun én Postgres-instans brukes i docker-stacken (`services.db`).
- [x] Flutter-klienten følger feature-først-strukturen (`auth`, `bridges`, `chat`, `contacts`).
- [x] Krypteringslaget er modulært slik at transport/Noise kan byttes uten å endre UI-kode.
- Returnerer nå `profile_id` og profilpayload i OTP-responsen, og standard
  profilnavn henter fornavn/e-post i stedet for «Privat», med oppdatert
  testdekning.
- La til dev-togglingsstøtte for `Messngr.Noise.DevHandshake`, inkludert
  runtime-overstyring, controller-guarding og enhetstester som verifiserer
  fallback til konfigurerte standardnøkler.
- Strammet inn `CurrentActor` til å kreve `Authorization: Noise` i
  samtaleendepunktene, la til kontakt→samtale→broadcast-test og verifiserte at
  `POST /api/conversations` avviser Bearer-tokens.
- Eksponerte `GET /api/account/me`, dokumenterte backend-oppsett og Noise-toggles
  i `docs/backend_setup.md`, og oppdaterte API-kontrakten.
- Dokumenterte arkitekturvalgene i `docs/architecture_alignment.md` med sjekklister
  for Phoenix-kontekster, Flutter-featurestrukturen og operasjonelle prinsipper
  (TLS/Noise-toggles, enkel Postgres-instans).
- La til `.env.example`, miljøtoggling i `docker-compose.yml` og HTTPS-oppsett i
  `config/runtime.exs` slik at TLS og Noise kan aktiveres/deaktiveres uten
  kodeendringer, samt oppdaterte backend-dokumentasjon for de nye bryterne.
- Oppdaterte `libmsgr_core` til å håndtere Noise-handshake automatisk i
  registreringsflyten, inkludert nye enhetstester og en dedikert
  `DevHandshake`-test som verifiserer backend-registriet.
- Enhanced the Microsoft Teams OAuth consent experience with resource-specific consent prompts,
  credential status surfacing, and revocation controls across the daemon, bridge metadata, and
  Flutter linking wizard, including updated unit tests for the Teams SDK and bridge session
  controller.
- Normalised Microsoft Teams chat and channel events into the canonical Msgr schema, capturing
  reply hierarchies, mentions, reactions, and meeting metadata while extending runtime tests to
  cover the richer payloads alongside webhook and poller dispatch flows. Introduced adaptive-card
  sanitisation and file-upload helpers so outbound Teams messages safely render HTML/cards and
  upload binary attachments with accompanying metadata for downstream consumers.

### Developer experience

- Updated the `libmsgr_core` key manager tests to rely on the built-in `MemorySecureStorage`, keeping the Mockito removal while restoring compatibility with `dart test`.
- Fixed the `libmsgr_cli` command runner tests by importing `dart:io` so the `Directory`-based option parsing compiles during `dart test`.
- Added `scripts/start_stack.sh` and `scripts/run_flutter.sh` to capture the
  recommended `docker compose`/`flutter run` incantations and documented the
  demoflyt (<1s send→ack, re-login) in `docs/backend_setup.md`.
- Ensured the `rust-gateway` Docker build installs `protobuf-compiler` in the
  builder stage so `cargo build --release` succeeds with the required `protoc`
  binary.
- Completed the CLI migration by deleting the legacy `libmsgr/tool` forwarder,
  fixing the standalone `libmsgr_cli` binary and pointing integration tests to
  `packages/libmsgr_cli/bin/msgr.dart`.
- Hardened the Flutter websocket send path with offline detection, queued
  retries (exponential backoff, max-attempt tracking), reconnection replay, and
  telemetry for retry outcomes so clients can surface resilient delivery states
  to users and logs.

### Observability

- Instrumented `ConversationChannel` typing and message ack flows with telemetry
  stubs and added a matching socket telemetry broadcaster in `libmsgr` so both
  backend and Flutter can hook into send→ack timelines.

### Produktplanlegging

- Etablerte `docs/product_backlog.md` for å samle integrasjoner, kanalinitiativer,
  admin/workspace-forbedringer og P2P/SRTP-satsinger med statusfelt som oppdateres
  når eksperimenter starter eller avsluttes.
- Opprettet `docs/webauthn_login_plan.md` med arkitektur for WebAuthn/passkey-
  innlogginger, IDP-redirects og websocket-push av «login fullført»-signaler fra
  backend til klient.
- Triagerte nøkkelidéer i `IDEAS.md` og markerte hvilke eksperimenter som er i
  discovery samt om de krever frontend- og/eller backend-arbeid.

### Continuous integration

- La til `Messngr.Metrics.Pipeline` med Telemetry-handlere, reporter-grensesnitt
  og Flutter/Elixir hooks for leveringslatens, leveringsrate, appstart og
  composer-ytelse, dokumentert i `architecture.md`.
- Fixed the socket telemetry docs to follow Elixir heredoc formatting so
  `mix format` succeeds.
- Corrected the Microsoft Teams bridge consent copy to remove invalid string
  continuations so `mix format` can process `Messngr.Bridges.Auth`.
- Restored the migrations formatter configuration so `mix format --check-formatted` can execute without error.
- Introduced a GitHub Actions workflow that runs `mix format --check-formatted`,
  `mix test`, `flutter format` and `flutter test` on pushes and pull requests.
- Oppdaterte dev-innloggingen i Flutter med backend-host-override via
  `BackendEnvironment.override`, lagring av Noise-token/session i
  `AuthIdentityStore` og nye enhetstester for persistensen.
- Forenklet `AppNavigation.redirectWhenLoggedIn` slik at direktechat kan brukes
  uten å velge workspace først, og dokumenterte flyten i
  `docs/frontend_chat_flow.md`.
- Herdet `ChatSocket` med tilkoblingshendelser og robust gjenoppkobling som
  oppdaterer `ChatViewModel`, inkludert nye widgettester for sanntidsstatus.
- Replaced the Microsoft Teams Graph poller with a webhook-driven change-notification pipeline,
  including reusable notification source abstractions, an in-memory transport for tests, and
  runtime coverage that validates real-time event delivery, acknowledgements, and token refresh
  integration.
- Added Microsoft Teams OAuth refresh handling that renews access tokens before expiry via the
  bridge daemon, persists refreshed credentials through the session manager, and exercises the
  new refresh flow with runtime tests covering the client, daemon, and credential vault updates.
- Wired the Slack and Microsoft Teams bridge health snapshots into queue request handlers,
  exposed connector helpers for retrieving runtime metrics, and introduced an Elixir
  `Messngr.Bridges.HealthReporter` that polls bridges and emits telemetry so operations
  dashboards receive per-client pending-event and connectivity data.
- Added Slack RTM runtime health snapshots and structured logging so operators can monitor
  websocket status, pending acknowledgements, and event freshness; added unit tests that
  exercise the diagnostics surface.
- Added Microsoft Teams Graph poller health reporting with consecutive error tracking, poll
  timestamps, and telemetry logging, plus runtime tests covering the health snapshot contract.
- Added Slack outbound file upload support that stages remote files via
  `files.getUploadURLExternal`, appends file blocks to `chat.postMessage`, and
  returns upload metadata so bridge workers can share attachments alongside
  text. Introduced unit coverage for file uploads and block composition.
- Sanitised Microsoft Teams outbound messages by normalising plain-text bodies
  into HTML, stripping disallowed tags/links from HTML payloads, and ensuring
  attachments are cleaned before POSTing to Graph. Added regression tests to
  verify the sanitiser output.
- Normalised Slack RTM and Microsoft Teams Graph events into Msgr's canonical
  message schema, covering message edits, deletions, reactions, attachments,
  mentions, and thread metadata so downstream consumers receive structured
  payloads with consistent fields across bridges. Added comprehensive unit
  tests for the new event mappers.
- Added `docs/slack_bridge_remaining_work.md` and `docs/teams_bridge_remaining_work.md` summarising
  the remaining Slack and Microsoft Teams bridge workstreams so contributors know which operational
  and product gaps to close before production pilots.
- Locked down media thumbnails by validating storage buckets/object keys during
  upload consumption, stripping untrusted pointers, and covering the flow with
  regression tests ahead of the alpha cut.
- Expanded the alpha readiness review with an actionable implementation queue covering backend, frontend, and DevEx blockers remaining before alpha.
- Updated the alpha readiness review with a status tracker that highlights the remaining backend, frontend, and DevEx work before inviting testers.
- Added a media retention pruner that periodically deletes expired uploads and
  their storage objects, with configurable sweep intervals and batch sizes plus
  tests and docs so alpha deployments do not accumulate orphaned blobs.
- Hardened media signing by requiring environment-provided secrets, binding
  checksums into presigned URLs, and covering the behaviour with tests and
  updated operator docs so alpha deployments can trust object storage links.
- Added a durable Flutter websocket outgoing message queue that persists
  unsent/ack-pending messages, retries with backoff on reconnect, and clears
  entries once delivery is confirmed.
- Enforced Noise handshake verification by default, removed legacy header fallbacks,
  and wired OTP challenges to rate limiting plus email/SMS delivery so passwordless
  auth is safe to expose to alpha testers.
- Added conversation channel payload caps and per-profile rate limiting so early testers
  cannot spam large messages or overwhelm realtime resources.
- Enabled the Prometheus exporter by default with runtime toggles and coverage so
  alpha operators can inspect latency and error metrics without manual config.
- Validated Noise device keys by normalising to URL-safe base64, storing SHA-256
  fingerprints, and expanding attester metadata so compromised devices can be
  audited and revoked before inviting alpha testers.
- Hardened chat persistence with retryable receipt fan-out, guarded pagination pivots,
  and a supervised watcher sweep so realtime occupancy stays accurate for alpha testers.
- Updated the alpha readiness review with the new chat persistence hardening milestones
  documented alongside the remaining backend, frontend, and DevEx gaps.
- Added an alpha readiness review in `docs/alpha_review.md` capturing backend, frontend, and DevEx
  gaps to close before inviting external testers.
- Stored Slack and Microsoft Teams bridge session tokens in the credential vault via a shared
  `Msgr.Connectors.SessionVault` helper so database snapshots no longer persist plaintext tokens and
  connector tests verify credential vault usage.
- Added `docs/libsignal_research.md` summarising libsignal protocol concepts, bridge
  considerations, and Rust client implications for future Msgr security work.
- Documented outstanding Slack and Microsoft Teams bridge work in `docs/bridge_status.md` so the
  new connectors have clear next steps before production rollout.
- Added Python Slack and Microsoft Teams bridge daemons with session managers,
  queue handlers, and comprehensive unit tests alongside documentation covering
  Slack token capture and Teams API behaviour so the new connectors have working
  end-to-end bridge workers ready for integration.
- Added Slack and Microsoft Teams bridge connectors with multi-instance routing,
  catalog updates, and queue facades so multiple workspaces/tenants can link to
  a single Msgr account with full test coverage.
- Added a bridge unlink API with catalog status annotations and Flutter disconnect
  controls so users can safely log out of connected bridges and refresh the list
  of available connectors without technical steps.
- Added a Flutter bridge center with catalog filters, embedded browser wizard,
  and credential forms backed by a new Bridge API client and widget tests so
  end users can link chat networks without technical setup.
- Implemented bridge OAuth browser endpoints, PKCE metadata handling, and an in-memory
  credential vault/inbox so sessions can complete start/callback flows and password-based
  connectors queue scrubbed credentials for daemon pickup, including controller and context tests.
- Added bridge catalog metadata, authentication session storage, and REST endpoints so clients can list bridges and bootstrap login flows with embedded browser/device-link guidance.
- Documented the current implementation status of the bridge authentication/UI plan so remaining backend, daemon, and client work is tracked explicitly.
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
  the registration flow (now shipped as `packages/libmsgr_cli/bin/msgr.dart`),
  and updated the integration test suite to use the new command for provisioning
  accounts.
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
- Introduced production-ready Slack RTM bridge client with Web API integrations,
  websocket event streaming, and OAuth code exchange helpers.
- Added Microsoft Teams Graph bridge client with polling-based change
  notifications, messaging helpers, and OAuth exchange support.

### Changed
- Extended bridge SDK test coverage with runtime unit tests for the Slack and
  Teams clients, verifying identity sync, messaging, and inbound event
  propagation behaviour.
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

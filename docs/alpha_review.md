# Alpha readiness review

## Executive summary
- Auth, identity, and device onboarding flows still lack production delivery, throttling, and full Noise session enforcement, so new users cannot securely self-onboard yet.
- Core chat persistence, delivery receipts, and media uploads are implemented, but several moderation, retention, and failure-handling paths need polish before friends can rely on them for day-to-day use.
- The Flutter client delivers a modern chat surface, yet navigation, authentication UI, offline cache hygiene, and error recovery must be stabilised to avoid trapping early testers.
- Tooling (mix/elixir toolchain, Flutter integration tests, observability defaults) needs configuration so contributors can reproduce bugs and operators can watch the alpha.

## Backend observations
### Authentication & identity
- `Messngr.Auth.start_challenge/1` stores OTP challenges and returns the raw code to the controller, but there is no integration that actually delivers the code via email/SMS or limits how often a target can request new codes. Alpha users would be blocked without wiring Swoosh or an SMS provider and adding hammer-based throttling in the controller layer.【F:backend/apps/msgr/lib/msgr/auth.ex†L20-L45】【F:backend/apps/msgr/lib/msgr/auth.ex†L250-L276】【F:backend/apps/msgr_web/lib/msgr_web/controllers/auth_controller.ex†L8-L47】【F:backend/config/config.exs†L7-L125】
- Noise sessions are optional (`noise_handshake_required: false`) and the `CurrentActor` plug still allows legacy headers, meaning requests can bypass device validation. Before an external alpha, flip the flag by default, remove the legacy path, and expand telemetry/rate-limiting for invalid tokens.【F:backend/config/config.exs†L7-L125】【F:backend/apps/msgr_web/lib/msgr_web/plugs/current_actor.ex†L1-L16】【F:backend/apps/msgr_web/lib/msgr_web/plugs/noise_session.ex†L35-L200】
- Device attachment accepts arbitrary `device_public_key` values without format checks or rotation policy; consider validating key length/type and persisting attestation metadata so testers can revoke compromised devices.【F:backend/apps/msgr/lib/msgr/accounts.ex†L96-L198】【F:backend/apps/msgr/lib/msgr/auth.ex†L232-L248】

### Messaging & realtime
- The conversation channel handles edits, reactions, pins, and receipts, but it does not enforce per-message rate limits or payload size caps—alpha spammers could exhaust resources. Introduce limits using Hammer or Phoenix Channel intercepts.【F:backend/apps/msgr_web/lib/msgr_web/channels/conversation_channel.ex†L18-L186】
- `Chat.send_message/3` wraps media uploads but assumes successful `ensure_pending_receipts`; there is no retry path if `Repo.insert_all/3` fails (e.g., transient DB issue). Consider moving receipt insertion to a separate transaction with retries or background job so delivery state is reliable.【F:backend/apps/msgr/lib/msgr/chat.ex†L68-L142】【F:backend/apps/msgr/lib/msgr/chat.ex†L1659-L1696】
- Message pagination defaults to 50 items and clamps to 200, yet there is no index on `(conversation_id, inserted_at)` beyond default? (verify migration). Also, `around_id` path fetches pivot via `Repo.get` without guarding deleted messages; if the pivot has been redacted the call returns `nil`. Handle `nil` to avoid crashing the client when navigating to removed pins.【F:backend/apps/msgr/lib/msgr/chat.ex†L410-L520】
- WebSocket typing timers, watcher reschedules, and presence updates exist, but there is no heartbeat/idle cleanup persisted server-side. Watching `last_activity_at` purely in memory risks stale watchers after restarts; add periodic cleanup job writing to DB or presence to keep channel occupancy accurate.【F:backend/apps/msgr_web/lib/msgr_web/channels/conversation_channel.ex†L18-L75】

### Media & storage
- Media uploads rely on locally-signed URLs with a static secret and optional SSE config. For alpha, rotate the signing secret per environment and document how to provision it outside repo defaults; also add checksum validation on download to prevent tampering.【F:backend/apps/msgr/lib/msgr/media/storage.ex†L1-L120】
- `Messngr.Media.Upload.creation_changeset/2` requires `retention_expires_at` but there is no job clearing expired records or S3 objects. Schedule pruning so alpha storage does not accumulate orphaned uploads.【F:backend/apps/msgr/lib/msgr/media/upload.ex†L16-L120】
- Thumbnail payload merging has a TODO and does not verify thumbnail origin/bucket; ensure thumbnails cannot point to arbitrary public URLs before exposing to testers.【F:backend/apps/msgr/lib/msgr/media/upload.ex†L200-L236】

### Families & bridges
- Family space controllers expose calendar/todo CRUD, yet there is no authorization check beyond profile membership; testers could access other household data if conversation IDs leak. Add per-space role validation and consider feature-flagging these endpoints for the chat-focused alpha.【F:backend/apps/msgr_web/lib/msgr_web/router.ex†L31-L66】
- Bridge controllers/session flows are extensive but depend on queue daemons; verify StoneMQ is part of the default docker-compose alpha stack, and add smoke tests to fail fast when daemons are absent.【F:backend/apps/msgr_web/lib/msgr_web/router.ex†L67-L86】

## Frontend observations
### Auth & navigation
- `AppNavigation` still wires legacy Redux-based flows (teams, rooms) in parallel with the new chat experience, and the guidance comments encourage manipulating the Navigator stack manually. Prune unused routes before alpha so testers land in the chat onboarding without encountering incomplete screens.【F:flutter_frontend/lib/config/AppNavigation.dart†L1-L190】
- `ChatPage` depends on `AuthGate` with `AccountIdentity` from providers, but there is no error UI if identity resolution fails (e.g., OTP expired). Add a first-run setup wizard that retries challenge verification or logs the user out cleanly.【F:flutter_frontend/lib/features/chat/chat_page.dart†L1-L120】

### Chat experience
- `ChatViewModel.bootstrap` hydrates cache, fetches channels, and connects realtime sequentially; if `_fetchChannels` throws, `_connectRealtime` never runs and watchers remain null. Wrap bootstrap steps with granular retry/backoff so the UI can recover from partial failures.【F:flutter_frontend/lib/features/chat/state/chat_view_model.dart†L105-L161】
- Optimistic reactions/pins update local state but assume the WebSocket command will succeed. Provide rollback handlers or disable controls when offline to avoid divergent state between devices.【F:flutter_frontend/lib/features/chat/state/chat_view_model.dart†L163-L198】
- Composer autosave uses SharedPreferences and Hive but `_suppressComposerPersistence` toggles without any guard; rapid thread switching could persist stale drafts into another conversation. Add integration tests covering thread swaps and ensure the autosave manager keys drafts per conversation/profile.【F:flutter_frontend/lib/features/chat/state/chat_view_model.dart†L75-L156】

### Offline & error handling
- Connectivity banner shows when cached messages exist, yet `fetchMessages` silently returns when `_thread` is null; initial bootstrap with no channel selected leaves the timeline empty without prompting the user to pick a conversation. Default to the first available thread or surface a placeholder CTA.【F:flutter_frontend/lib/features/chat/state/chat_view_model.dart†L105-L161】
- Media uploads rely on `ChatMediaUploader` but there is no visual progress state in `_ChatView`; ensure upload failures surface toasts and allow retry before sharing to friends.【F:flutter_frontend/lib/features/chat/state/chat_view_model.dart†L22-L55】【F:flutter_frontend/lib/features/chat/chat_page.dart†L34-L120】

## DevEx, testing & observability
- `mix test` currently fails because the container lacks Erlang/Elixir despite `mise` warnings. Document required toolchain versions or ship `.tool-versions`/Docker instructions so contributors can run tests locally.【579699†L1-L13】
- Backend Hammer rate-limiter is configured but unused; wire it into auth/message endpoints and add telemetry dashboards (Prometheus is disabled by default).【F:backend/config/config.exs†L98-L125】
- Flutter project has widget/unit tests, yet there is no automated integration test hitting the live backend; add a golden flow that creates accounts, sends a message, and verifies timeline rendering so alpha regressions are caught early.【F:flutter_frontend/test/chat_thread_test.dart†L1-L200】
- Observability stack (Prometheus/OpenObserve) is documented, but `config :msgr_web, :prometheus, enabled: false` disables metrics out of the box. Flip this on for alpha or provide environment overrides so latency/errored request charts work during testing.【F:backend/config/config.exs†L98-L115】

## Suggested next steps before inviting testers
1. Finish the passwordless flow: integrate email/SMS delivery, add per-target throttling, enforce Noise sessions by default, and build device revocation UI.
2. Harden chat operations with request limits, retry-safe delivery receipts, heartbeat cleanup, and defensive checks around deleted pivots and media thumbnails.
3. Simplify the Flutter navigation/auth surface, add bootstrap recovery, and cover offline/error cases with UI affordances and tests.
4. Enable and document the observability pipeline, ensure mix/Flutter tests run in CI, and provide quick-start scripts so friends can self-host the alpha stack.

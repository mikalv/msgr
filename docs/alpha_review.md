# Alpha readiness review

## Executive summary
- Core authentication, device onboarding, and chat persistence now cover retry/backoff and watcher cleanup so the remaining backend focus is on ancillary features and storage hardening.
- The Flutter client requires navigation pruning, better bootstrap recovery, and clearer offline/error flows so alpha testers are not stranded on blank timelines or failed uploads.
- Family/bridge surfaces still need stronger authorisation and environment validation to ensure non-chat features do not leak data or fail silently during early trials.
- Developer experience gaps—toolchain documentation, end-to-end Flutter coverage, and bridge daemon smoke tests—remain blockers for contributors spinning up the stack quickly.

## Progress tracker

### Completed for alpha
- ✅ Passwordless delivery with Hammer throttling and default Noise session enforcement.
- ✅ Device key normalisation with fingerprint storage for audit/revocation.
- ✅ Conversation payload caps, per-profile rate limiting, and media retention pruning.
- ✅ Prometheus exporter enabled by default with runtime overrides documented.
- ✅ Media signing secrets sourced from the environment with checksum binding.
- ✅ Chat persistence now retries receipt fan-out, guards pagination pivots, and sweeps idle watchers.

### Still outstanding
- 🔲 Lock down media thumbnails and family/bridge controllers before exposing non-chat features.
- 🔲 Stabilise the Flutter onboarding/navigation flow and cover offline/error recovery with tests.
- 🔲 Improve contributor experience with toolchain docs, integration tests, and StoneMQ/daemon smoke checks.

## Backend observations
### Authentication & identity
- [x] OTP challenges now deliver via Swoosh-backed email with Hammer throttling, closing the previous gap where codes were never sent or rate limited.【F:backend/apps/msgr/lib/msgr/auth.ex†L20-L45】【F:backend/apps/msgr/lib/msgr/auth.ex†L250-L276】【F:backend/apps/msgr_web/lib/msgr_web/controllers/auth_controller.ex†L8-L47】【F:backend/config/config.exs†L7-L125】
- [x] Noise sessions are now required by default and the legacy header bypass was removed, so device validation is enforced on every request.【F:backend/config/config.exs†L7-L125】【F:backend/apps/msgr_web/lib/msgr_web/plugs/current_actor.ex†L1-L16】【F:backend/apps/msgr_web/lib/msgr_web/plugs/noise_session.ex†L35-L200】
- [x] Device attachment now normalises Noise keys, stores SHA-256 fingerprints, and validates key format so compromised hardware can be audited and revoked.【F:backend/apps/msgr/lib/msgr/accounts.ex†L96-L198】【F:backend/apps/msgr/lib/msgr/auth.ex†L232-L248】

### Messaging & realtime
- [x] The conversation channel now enforces per-message Hammer limits and payload caps, preventing alpha testers from spamming oversized messages while keeping edits, reactions, pins, and receipts responsive.【F:backend/apps/msgr_web/lib/msgr_web/channels/conversation_channel.ex†L18-L186】
- [x] `Chat.send_message/3` now wraps receipt fan-out in a retry helper so transient insert errors are retried before returning control to the caller.【F:backend/apps/msgr/lib/msgr/chat.ex†L78-L113】【F:backend/apps/msgr/lib/msgr/chat.ex†L1715-L1744】【F:backend/apps/msgr/lib/msgr/retry.ex†L1-L68】
- [x] Message pagination still leverages the existing composite index but now guards deleted/foreign pivots so `around_id/3` gracefully falls back when a message disappears.【F:backend/apps/msgr/lib/msgr/chat.ex†L360-L520】【F:backend/apps/msgr/lib/msgr/chat.ex†L1061-L1074】
- [x] Idle watchers are swept by a new ETS pruner and supervised `WatcherPruner` process so stale occupancy is broadcast out without manual intervention.【F:backend/apps/msgr/lib/msgr/chat.ex†L911-L1008】【F:backend/apps/msgr/lib/msgr/chat/watcher_pruner.ex†L1-L99】【F:backend/apps/msgr/lib/msgr/application.ex†L10-L37】

### Media & storage
- [x] Media signing now pulls per-environment secrets, binds checksums into signatures, and documents the required configuration so downloads cannot be tampered with silently.【F:backend/apps/msgr/lib/msgr/media/storage.ex†L1-L120】
- [x] A retention pruner now sweeps expired uploads and thumbnails on a configurable cadence, keeping alpha storage tidy without manual cleanup.【F:backend/apps/msgr/lib/msgr/media/upload.ex†L16-L120】
- [ ] Thumbnail payload merging has a TODO and does not verify thumbnail origin/bucket; ensure thumbnails cannot point to arbitrary public URLs before exposing to testers.【F:backend/apps/msgr/lib/msgr/media/upload.ex†L200-L236】

### Families & bridges
- [ ] Family space controllers expose calendar/todo CRUD, yet there is no authorization check beyond profile membership; testers could access other household data if conversation IDs leak. Add per-space role validation and consider feature-flagging these endpoints for the chat-focused alpha.【F:backend/apps/msgr_web/lib/msgr_web/router.ex†L31-L66】
- [ ] Bridge controllers/session flows are extensive but depend on queue daemons; verify StoneMQ is part of the default docker-compose alpha stack, and add smoke tests to fail fast when daemons are absent.【F:backend/apps/msgr_web/lib/msgr_web/router.ex†L67-L86】

## Frontend observations
### Auth & navigation
- [ ] `AppNavigation` still wires legacy Redux-based flows (teams, rooms) in parallel with the new chat experience, and the guidance comments encourage manipulating the Navigator stack manually. Prune unused routes before alpha so testers land in the chat onboarding without encountering incomplete screens.【F:flutter_frontend/lib/config/AppNavigation.dart†L1-L190】
- [ ] `ChatPage` depends on `AuthGate` with `AccountIdentity` from providers, but there is no error UI if identity resolution fails (e.g., OTP expired). Add a first-run setup wizard that retries challenge verification or logs the user out cleanly.【F:flutter_frontend/lib/features/chat/chat_page.dart†L1-L120】

### Chat experience
- [ ] `ChatViewModel.bootstrap` hydrates cache, fetches channels, and connects realtime sequentially; if `_fetchChannels` throws, `_connectRealtime` never runs and watchers remain null. Wrap bootstrap steps with granular retry/backoff so the UI can recover from partial failures.【F:flutter_frontend/lib/features/chat/state/chat_view_model.dart†L105-L161】
- [ ] Optimistic reactions/pins update local state but assume the WebSocket command will succeed. Provide rollback handlers or disable controls when offline to avoid divergent state between devices.【F:flutter_frontend/lib/features/chat/state/chat_view_model.dart†L163-L198】
- [ ] Composer autosave uses SharedPreferences and Hive but `_suppressComposerPersistence` toggles without any guard; rapid thread switching could persist stale drafts into another conversation. Add integration tests covering thread swaps and ensure the autosave manager keys drafts per conversation/profile.【F:flutter_frontend/lib/features/chat/state/chat_view_model.dart†L75-L156】

### Offline & error handling
- [ ] Connectivity banner shows when cached messages exist, yet `fetchMessages` silently returns when `_thread` is null; initial bootstrap with no channel selected leaves the timeline empty without prompting the user to pick a conversation. Default to the first available thread or surface a placeholder CTA.【F:flutter_frontend/lib/features/chat/state/chat_view_model.dart†L105-L161】
- [ ] Media uploads rely on `ChatMediaUploader` but there is no visual progress state in `_ChatView`; ensure upload failures surface toasts and allow retry before sharing to friends.【F:flutter_frontend/lib/features/chat/state/chat_view_model.dart†L22-L55】【F:flutter_frontend/lib/features/chat/chat_page.dart†L34-L120】

## DevEx, testing & observability
- [ ] `mix test` currently fails because the container lacks Erlang/Elixir despite `mise` warnings. Document required toolchain versions or ship `.tool-versions`/Docker instructions so contributors can run tests locally.【579699†L1-L13】
- [x] Hammer rate limiting now guards auth and conversation flows, and Prometheus is enabled by default so dashboards can surface throttle metrics for alpha ops.【F:backend/config/config.exs†L98-L125】
- [ ] Flutter project has widget/unit tests, yet there is no automated integration test hitting the live backend; add a golden flow that creates accounts, sends a message, and verifies timeline rendering so alpha regressions are caught early.【F:flutter_frontend/test/chat_thread_test.dart†L1-L200】
- [x] Prometheus/OpenObserve can now be toggled via runtime env without editing config files, making metrics available to testers by default.【F:backend/config/config.exs†L98-L115】

## Suggested next steps before inviting testers
1. Harden chat persistence: add retry/backoff for receipt insertion, guard pagination pivots, and introduce watcher cleanup to keep realtime occupancy accurate.
2. Secure ancillary surfaces by validating thumbnail sources, tightening family space authorisation, and shipping StoneMQ/bridge smoke tests in the default stack.
3. Streamline the Flutter experience with trimmed navigation, onboarding recovery flows, and offline/error UI backed by new widget/integration coverage.
4. Unblock contributors by documenting the Elixir/Flutter toolchains, adding an end-to-end Flutter happy-path test, and scripting the local alpha environment.

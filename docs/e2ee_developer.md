# E2EE developer runbook (1:1 text)

Practical notes for working on personal-mode end-to-end encryption.
Normative crypto and wire format: [e2ee_spec.md](e2ee_spec.md).
HTTP shapes: [api_contract.md](api_contract.md) (E2EE section).

**Scope today:** personal 1:1 text only. Media CEK (#236), Sender Keys / groups
(#237), and team/business mode stay plaintext.

## Intent

- Server is an **opaque relay**: store and fan-out `payload.e2ee`; never decrypt.
- Clients bootstrap with an **XX-style in-band handshake** (`init` / `init_ack`).
  The optional key directory must never block send.
- First send without a session is handshake-only; plaintext is queued locally
  until `init_ack`, then flushed as `msg`.

## Architecture map

| Layer | Location | Role |
|-------|----------|------|
| Crypto core | `flutter_frontend/packages/libmsgr_core/lib/src/crypto/e2ee/` | Double Ratchet, XX handshake, envelope codec, `E2eeService` |
| SQLCipher adapter | `libmsgr` `OmemoDao` + `OmemoE2eeSessionStore` | Persist ratchets / device list / trust / own keys |
| Chat UI hooks | `packages/core/.../chat_view_model.dart` | Encrypt private DMs; decrypt on receive; send `init_ack` |
| Key directory API | `MessngrWeb.E2eeController` + `Messngr.E2ee` | Optional prekey bundles (empty list = success) |
| Message relay | `Messngr.Chat` + `Message` changeset | `kind: :encrypted`, force `body: ""`, require `payload.e2ee` |
| Fan-out hint | `Chat.maybe_annotate_e2ee_fanout/4` | For `rid: "*"`, set `metadata.e2ee_fanout_device_ids` from key directory |

```
prepareSend → POST /api/conversations/:id/messages {kind:encrypted, body:"", payload}
           → peer handleIncoming → optional init_ack message
           → prepareSend (msg) with queued plaintext
```

## Public HTTP surfaces

Authenticated with `Authorization: Bearer <access JWT>` (same as other `/api`
actor routes).

| Method | Path | Notes |
|--------|------|-------|
| `PUT` | `/api/v1/e2ee/keys` | Upsert device IK/SPK; replace unused OPK batch |
| `GET` | `/api/v1/e2ee/bundles/:profile_id` | One bundle per device; **pops** one unused OPK when present; `[]` OK |
| `GET` | `/api/v1/e2ee/keys/count?device_id=` | Remaining unused OPKs (`device_id` required) |
| `POST` | `/api/conversations/:id/messages` | `kind: "encrypted"`, empty body, opaque `payload.e2ee` |

Key material is standard Base64 (also accepts URL-safe without padding on
upload). Server accepts 32- or 64-byte decoded keys only.

## Client usage

```dart
// Wire SQLCipher store (libmsgr)
final e2ee = createSqlE2eeService(keyManager: keyManager, dao: omemoDao);
await e2ee.ensureReady();

// Outbound (no session → init + queued plaintext)
final prepared = await e2ee.prepareSend(
  peerProfileId: peerId,
  plaintext: text,
);
// POST message with kind: prepared.kind, payload: prepared.payload

// Inbound
final result = await e2ee.handleIncoming(
  peerProfileId: peerId,
  payload: envelopeMap,
);
// if result.ackPayload != null → send that envelope as another encrypted message
```

UI gate (chat view model): E2EE applies only when the thread is **private**,
**direct**, and a peer profile id is known. Missing `E2eeService` → plaintext path.

## Verification

| Layer | Command |
|-------|---------|
| Crypto unit/integration | `cd flutter_frontend/packages/libmsgr_core && dart test test/e2ee` |
| Opaque REST/DB relay | `cd backend && PROMETHEUS_ENABLED=false mix test apps/msgr_web/test/msgr_web/controllers/e2ee_wire_flow_test.exs` |
| Controller + encrypted create | `… mix test apps/msgr_web/test/msgr_web/controllers/e2ee_controller_test.exs` |
| Full HTTP E2E | `./scripts/run_e2ee_e2e.sh` |

`run_e2ee_e2e.sh` starts Phoenix with `BOT_AUTH_SECRET` (default
`dev-bot-secret-e2e`), waits on `/health`, then runs
`e2ee_http_e2e_test.dart`. Override with `E2EE_E2E_BASE_URL` / `PORT` /
`BOT_AUTH_SECRET`.

## Constraints and pitfalls

- **Do not gate send on key directory.** Empty bundles and missing keys are
  normal; fall back to XX `init`.
- **Never put plaintext in `body` for encrypted messages.** Server overwrites
  `body` to `""`; envelope lives only under `payload.e2ee`.
- **Persist ratchet state after every encrypt/decrypt.** Reusing stale
  in-memory sessions breaks the ratchet (`OmemoRatchets` / session store).
- **Self-device sync:** each `msg` must wrap the payload key to the sender’s
  other devices as well as peer devices (spec §2 / §4).
- **Prometheus conflict:** stop the dev server or set `PROMETHEUS_ENABLED=false`
  before ExUnit (port 9568).
- **Bot auth for E2E:** `POST /api/v1/auth/bot-token` needs
  `BOT_AUTH_SECRET` configured on the server; script sets it for you.
- **Out of scope:** personal media has no CEK wrapping yet; team chats remain
  plaintext; ClamAV only covers team media ([media_virus_scan.md](media_virus_scan.md)).

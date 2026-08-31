# Realtime channels (Phoenix) developer runbook

How WebSocket topics map to modules on the **primary** socket
(`MessngrWeb.UserSocket` at `/socket`). Complements
[api_contract.md](api_contract.md) (HTTP + high-level WS) and
[rtc.md](rtc.md) (WebRTC signalling).

## Intent

- One Phoenix socket serves both personal and team clients.
- **Mounted** topics are the contract for clients and ops; source files that
  are not registered must not be treated as live API.
- Team chat realtime works today via `TeamsWeb.*` channels. Personal-mode
  conversation realtime is **not** mounted on the socket (see gap below).

## Mounted topics (`MessngrWeb.UserSocket`)

Verified in `backend/apps/msgr_web/lib/msgr_web/channels/user_socket.ex`:

| Topic pattern | Module | Role |
|---------------|--------|------|
| `msgr:device` | `MessngrWeb.DeviceChannel` | Device/lobby-style channel |
| `rtc:*` | `MessngrWeb.RTCChannel` | WebRTC signalling (see `rtc.md`) |
| `channel:*` | `TeamsWeb.ChatChannel` | Team channel messages / typing / reactions |
| `team:*` | `TeamsWeb.TeamChannel` | Team-wide structural events |
| `presence:*` | `TeamsWeb.PresenceChannel` | Per-team online presence |

`TeamsWeb.UserSocket` (teams endpoint) also registers `channel:*` →
`TeamsWeb.ChatChannel` and `conv:*` → `TeamsWeb.ConversationChannel` (teams
tenant model — not personal `Messngr.Chat`).

### Connect auth

1. **Preferred:** connect params `{ "token": "<access JWT>" }` — Guardian
   access token; assigns `account_id` / `profile_id` from `sub` / `pid`.
2. **Gateway path:** `account_id` (+ optional `profile_id`, `device_id`,
   `session_id`) after Rust gateway validation.

Join authorization is per-channel (membership / tenant), not via trusted
client HTTP headers.

## Team chat (`channel:{channel_id}`)

**Module:** `TeamsWeb.ChatChannel`

- Join requires a **tenant prefix**: from socket `:tenant` (JWT) or join
  payload `team_slug` → `TeamManagement.get_team_by_slug/1` →
  `team.schema_name`. Missing prefix → `{reason: "tenant_not_resolved"}`.
- Access: channel exists in tenant schema + `has_access?/3` for the tenant
  profile.
- Client events (incoming): `message:create` (alias of `new:message`),
  `new:thread_reply`, `toggle:reaction`, `typing:start` / `typing:stop`,
  `update:read_cursor`, `ping`.
- Server broadcasts: `new:message`, `new:thread_reply`, `reaction:updated`,
  `typing:update`, `read_cursor:updated`. REST controllers may also
  `Endpoint.broadcast("channel:#{id}", …)` for edits/pins/typing.

**Team-wide:** join `team:{slug}` (`TeamsWeb.TeamChannel`) for
`new:channel`, `member:joined` / `member:left`, `channel:updated`, and
sidebar hints such as `channel:new_message`.

**Presence:** join `presence:{team_slug}` (`TeamsWeb.PresenceChannel`);
membership required.

Example (team bot / CLI style):

```text
connect /socket/websocket with token=<JWT>
join topic=team:acme          payload={}
join topic=channel:<uuid>     payload={"team_slug":"acme"}
join topic=presence:acme      payload={}
```

## Team HTTP authz (related)

Scoped routes under `/api/teams/:slug/…` use pipeline `:tenant`:

1. `MessngrWeb.Plugs.TenantFromSlug` — resolve team; 404 if missing; assigns
   `:current_team`, `:tenant_prefix`.
2. `MessngrWeb.Plugs.RequireTeamMembership` — account must have tenant profile
   + public `TeamMembership`; 403 otherwise; assigns `:current_team_profile`,
   `:current_team_membership`.

This closed SEC-2 (cross-tenant IDOR). Invite redeem and
`GET|POST /api/teams` stay on `:actor` only by design.

## Personal conversation gap (important)

| Piece | Location | Status |
|-------|----------|--------|
| Domain PubSub | `Messngr.Chat` topic `conversation:{id}` | Broadcasts on create/update/delete/reactions/… |
| Channel module | `MessngrWeb.ConversationChannel` | Implements personal + hybrid logic; **join clause is `"channel:" <> id`**, not `conversation:` |
| Socket mount | `MessngrWeb.UserSocket` | **Does not** register `MessngrWeb.ConversationChannel` or any `conversation:*` topic |
| Flutter personal socket | `packages/core/.../chat_socket.dart` (and app copy) | Joins `conversation:{conversationId}` |

Consequences for developers:

- Joining `conversation:…` on `/socket` has **no** handler → Phoenix join
  error. Personal UI must rely on REST (and any future remount) until this
  is fixed.
- Remounting personal realtime is not a one-liner: either register a
  `conversation:*` channel that subscribes to `Messngr.Chat` PubSub, or
  change the client to a topic that is mounted and wired to personal
  membership. Today `channel:*` is owned by **team** `TeamsWeb.ChatChannel`
  (requires tenant).
- `MessngrWeb.ConversationChannel` still contains useful event shapes
  (`message_created`, typing, watchers, E2EE `message:create`) used by older
  docs/tests, but it is **orphaned** until re-registered. Parked suite:
  `apps/msgr_web/test/pending_failures/conversation_channel_test.exs.disabled`.

Do not document `conversation:{id}` as a live join topic without fixing the
mount. Prefer this runbook + the corrected WebSocket section in
`api_contract.md`.

## Constraints and pitfalls

- **Topic collision:** `channel:*` is team-only on `MessngrWeb.UserSocket`.
  Do not assume personal conversation IDs work there without a tenant.
- **Two ConversationChannel modules:** `MessngrWeb.ConversationChannel`
  (personal/hybrid, unmounted) vs `TeamsWeb.ConversationChannel` (`conv:*` on
  the teams socket). Name carefully in PRs.
- **PubSub vs Phoenix topic:** `conversation:{id}` PubSub messages are
  Elixir tuples (`{:message_created, msg}`, …). They only reach WS clients
  if a channel process subscribes and `push/3`es JSON events.
- **Prometheus:** local ExUnit + channel tests often need
  `PROMETHEUS_ENABLED=false` if port 9568 is taken.
- **E2EE:** encrypted personal messages use REST
  `POST /api/conversations/:id/messages` today; see
  [e2ee_developer.md](e2ee_developer.md). Live WS encrypt path depends on
  remounting personal realtime.

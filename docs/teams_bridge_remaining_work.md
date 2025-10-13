# Microsoft Teams Bridge Remaining Work

Existing building blocks already cover the core Teams bridge flow:

- `bridge_sdks/python/msgr_teams_bridge` ships a Microsoft Graph client, polling daemon, and
  session manager with thorough unit coverage for link, send, and acknowledgement paths.
- The Elixir connector `Msgr.Connectors.TeamsBridge` (`backend/apps/msgr/lib/msgr/connectors/teams_bridge.ex`)
  exposes multi-tenant routing, capability sync, and StoneMQ queue integration.
- API exploration notes live in `docs/teams_api_notes.md`, outlining the Microsoft Graph surfaces we
  target for messaging and roster sync.

The remaining work items below highlight what needs to ship before piloting the Teams bridge in a
production tenant.

## OAuth & Consent Experience
- Complete the embedded browser OAuth flow with resource-specific consent prompts when tenants
  require RSC scopes, and surface clear guidance/errors in the linking wizard.
- Refresh tokens are now persisted in the bridge credential vault and automatically renewed by the
  Teams bridge daemon; continue wiring the consent UI to surface credential status and revocation
  controls for operators.

## Real-time Event Delivery
- Replace the current long-polling loop with Microsoft Graph change notifications delivered via a
  webhook relay or websocket gateway so message latency matches other bridges.
- Backfill missed events during webhook outages by reconciling Graph delta queries against the bridge
  data store.

## Message Surface & Attachments
- Normalise Teams chat/channel payloads into Msgr's canonical schema, including replies, mentions,
  reactions, and meeting-specific metadata.
- Implement outbound file uploads and adaptive-card/HTML sanitisation so rich Teams messages round-trip
  correctly.

## Operational Hardening
- Document deployment topologies for sharding by tenant or geography and how to handle dedicated
  resource mailboxes where Teams stores compliance copies.

## Testing & Compliance
- Stand up an automated integration test suite that exercises the daemon against a Microsoft 365
  developer tenant covering personal chats, group chats, and channel threads.
- Capture mock fixtures for subscription renewals, throttling responses, and compliance edge cases so
  regression tests remain deterministic without external network access.

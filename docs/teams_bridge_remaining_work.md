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
- ✅ Completed the embedded browser OAuth flow with resource-specific consent prompts when tenants
  require RSC scopes, and surfaced clear guidance/errors in the linking wizard.
- ✅ Surfaced bridge credential status and revocation controls in the consent UI now that refresh
  tokens are persisted in the credential vault and automatically renewed by the Teams bridge daemon.

## Real-time Event Delivery
- Harden the new change-notification pipeline by persisting Graph webhook subscription state and
  running the relay across multiple bridge workers so message fan-out survives process restarts.
- Backfill missed events during webhook outages by reconciling Graph delta queries against the bridge
  data store.

## Message Surface & Attachments
- Expand contract fixtures that exercise the new canonical normaliser across message edits,
  multi-tenant channel threads, and compliance copies so regressions are caught before releases.
- Harden the adaptive-card pipeline by validating card templates, localised text rendering, and
  large file uploads in integration environments before enabling production tenants.

## Operational Hardening
- Document deployment topologies for sharding by tenant or geography and how to handle dedicated
  resource mailboxes where Teams stores compliance copies.

## Testing & Compliance
- Stand up an automated integration test suite that exercises the daemon against a Microsoft 365
  developer tenant covering personal chats, group chats, and channel threads.
- Capture mock fixtures for subscription renewals, throttling responses, and compliance edge cases so
  regression tests remain deterministic without external network access.

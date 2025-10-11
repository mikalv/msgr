# Telegram and Matrix Integration Kick-off

## Goals
- Establish thin HTTP clients for Telegram Bot API and Matrix Client API that Msgr can call from background workers.
- Provide automated tests around the critical request paths so we can iterate on the bridge without hitting the real services.
- Document the MVP flows (login, sync, outbound messaging) that are now unblocked.

## Telegram
- `Messngr.Connectors.Telegram.Client.send_message/4` posts messages through the Bot API with optional formatting helpers.
- `Messngr.Connectors.Telegram.Client.get_updates/2` fetches inbound events with filter options so consumers can manage offsets.
- Both functions accept a custom Finch pool and base URL to simplify dependency injection for future supervisors and for tests.

## Matrix
- `Messngr.Connectors.Matrix.Client.login/3` implements password-based login and returns the raw response map containing the access token and device metadata.
- `Messngr.Connectors.Matrix.Client.sync/3` performs incremental sync requests with caller-provided query parameters, giving the ingest pipeline control over long-polling behaviour.
- `Messngr.Connectors.Matrix.Client.send_event/4` sends room events with caller supplied transaction IDs, defaulting to generated UUIDs when not provided.

## Next Steps
1. Wire the clients into supervised GenServers that maintain cursors per account and push events onto the internal message bus.
2. Extend the account linking flow to capture Telegram bot tokens and Matrix access tokens using the new clients for validation.
3. Add persistence for sync cursors and idempotency keys so the bridge can recover from restarts without duplicating events.
4. Enrich telemetry spans for HTTP requests to surface latency and error rates per platform.

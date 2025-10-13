# Slack Bridge Remaining Work

The repository already contains a substantial Slack bridge implementation:

- The Python daemon in `bridge_sdks/python/msgr_slack_bridge` exposes an RTM/Web API client,
  session helpers, and queue handlers that satisfy the existing unit tests.
- The Elixir connector `Msgr.Connectors.SlackBridge` (see `backend/apps/msgr/lib/msgr/connectors/slack_bridge.ex`)
  wires account linking, outbound messaging, and acknowledgement flows into StoneMQ.
- Operator guidance for capturing RTM tokens lives in `docs/slack_token_capture_plan.md`.

The lists below capture what is still missing before we can confidently bridge live Slack workspaces.

## Account Linking & Token Capture
- Finish the embedded-browser capture wizard described in `docs/slack_token_capture_plan.md` and
  integrate it with the Flutter bridge centre so end users no longer paste tokens manually.
- Store captured tokens exclusively in the credential vault and expose revoke/refresh tooling in the
  bridge dashboard to invalidate secrets when a workspace is unlinked.

## Event Normalisation
- Map Slack RTM events into Msgr's canonical message schema, including thread replies, edits,
  reactions, and message deletions, so downstream consumers receive uniform payloads.
- Ensure Slack-specific metadata (files, blocks formatting, user mentions) is normalised or preserved
  in a structured form that Msgr clients can render.

## Outbound Feature Parity
- Implement message sending for attachments beyond plain text (files, images, snippets) with proper
  upload handling and share-link integration.
- Translate Msgr rich-text entities into Slack's formatting blocks and surface delivery failures back
  to the queue so retry logic can react appropriately.

## Reliability & Operations
- Wire the new runtime health snapshot into the bridge supervisor and export metrics to the
  monitoring stack so operators receive alerts for websocket reconnect storms, stale pending
  events, and growing acknowledgement latency.
- Document scaling guidance for running multiple RTM sessions per daemon instance and how to shard
  workspaces when reaching Slack's connection caps.

## Testing & QA
- Add end-to-end integration tests that exercise the daemon against a real Slack workspace (can
  be gated behind environment flags) to verify linking, message fan-out, and acknowledgements.
- Capture fixtures for representative RTM payloads so regression tests cover parsing edge cases such
  as multi-part threads, shared channels, and enterprise grid IDs.

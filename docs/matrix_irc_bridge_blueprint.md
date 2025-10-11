# Matrix and IRC Bridge Blueprint

## Purpose
This document defines the initial pair of Msgr bridges, targeting Matrix and IRC. It covers the
minimum viable transport features, queue mappings, and operational constraints so that both
bridges can move plaintext chat traffic between Msgr and the external networks without media
payload support. The blueprint also introduces a canonical `msgr://` URL scheme we can reuse to
reference channels, identities, bridge resources, and individual messages across the product.

## Scope Overview
- **Matrix Bridge**: Connects to homeservers via the [Matrix Client-Server API](https://spec.matrix.org/latest/client-server-api/),
  focusing on room timelines, membership sync, and typing notifications. File transfer, VoIP,
  and end-to-end encryption are out-of-scope for this initial iteration.
- **IRC Bridge**: Connects to traditional IRC networks using the IRCv3 capability set (SASL,
  tags, message IDs when available). Media payloads are not forwarded; we optionally emit
  placeholder text to preserve context.

Both bridges share the Msgr StoneMQ envelope contracts defined in `bridge_architecture.md` and
rely on the Go bridge SDK for queue integration.

## Functional Goals
1. **Message Ingestion**
   - Subscribe to Msgr `outbound_message` envelopes and translate them into Matrix events or
     IRC `PRIVMSG` commands.
   - Collect inbound Matrix timeline events / IRC messages and publish them as
     `inbound_message` envelopes.
2. **Identity Mapping**
   - Maintain a mapping between Msgr identities and remote accounts to enable puppeting or
     relay-style bridging.
   - Support user display name sync (Matrix) and nick tracking (IRC) when exposed by the
     protocol.
3. **Channel Lifecycle**
   - Allow Msgr conversations to attach to Matrix rooms or IRC channels via bridge
     configuration records.
   - Handle join/part events, membership updates, and topic changes (IRC) to keep the Msgr
     channel metadata consistent.
4. **Operational Safety**
   - Gate outbound traffic on per-bridge rate limits and connection health metrics.
   - Expose structured logs and metrics to Msgr observability pipelines.

## Non-Goals (MVP)
- Media, voice, and video relaying (provide future hooks for uploading to Msgr media service
  and sending shareable URLs instead).
- Matrix E2EE key management.
- IRC CTCP actions beyond `/me` emotes (supported through message tags only if advertised).
- Threaded replies; all messages are linear until follow-up iteration.

## Architecture Snapshot
```
+----------------------+          +----------------------+          +----------------------+
|   Msgr StoneMQ       |          |   Matrix Bridge Daemon|          |     Matrix Server    |
|----------------------|          |-----------------------|          |----------------------|
| outbound_message ----|--------->| sendWorker            |--------->| /_matrix/client/v3   |
| inbound_message <----|--------- | timelinePoller        |<---------| Sync/Long Poll       |
| ack_receipt ---------|<---------| ackWorker             |          |                      |
+----------------------+          +----------------------+          +----------------------+

+----------------------+          +----------------------+          +----------------------+
|   Msgr StoneMQ       |          |    IRC Bridge Daemon  |          |       IRC Server      |
|----------------------|          |-----------------------|          |----------------------|
| outbound_message ----|--------->| privmsgWorker         |--------->| PRIVMSG               |
| inbound_message <----|--------- | ircListener           |<---------| 353/366 RPL, PRIVMSG  |
| ack_receipt ---------|<---------| ackWorker             |          |                      |
+----------------------+          +----------------------+          +----------------------+
```

## Data Model Contracts
### Msgr Configuration Records
| Field | Matrix | IRC | Notes |
|-------|--------|-----|-------|
| `bridge_id` | `matrix` | `irc` | Identifies daemon deployment and maps to queue topics (`bridge/<service>/<bridge_id>/<action>`). |
| `channel_ref` | `msgr://channels/<workspace>/bridge/matrix/<room_id>` | `msgr://channels/<workspace>/bridge/irc/<server>/<channel>` | Canonical Msgr channel URL. |
| `remote_pointer` | Fully qualified room ID (`!room:server`) | `{network}/{channel}` | Used when reconnecting or auditing. |
| `puppet_mode` | `relay` or `full` | `relay` | IRC starts in relay mode; future puppet expansions possible. |
| `capabilities` | JSON map of supported Matrix feature flags | IRC capability list (e.g., `sasl`, `message-tags`) | Advertised by the daemon at runtime. |

### Queue Envelope Payloads
- **`outbound_message`**: `body`, `formatted_body` (Matrix HTML), `mentions`, optional
  `reply_to`. For IRC we drop rich formatting, flattening to plaintext.
- **`inbound_message`**: `remote_id`, `sender_identity`, `timestamp`, `body`, optional
  `thread_root`. IRC `message-tags` populate `remote_id` when `msgid` is present; otherwise we
  synthesize deterministic IDs based on server + timestamp.
- **`ack_receipt`**: Standardised for both bridges to confirm delivery back to Msgr clients.

## Connection Lifecycle
### Matrix
1. Authenticate via access token or password/refresh token pair stored in the credential vault.
2. Register a sync loop (long polling or `/sync` with sliding token) per configured room.
3. Push outbound events using `/send/m.room.message` for text and `/typing` for presence.
4. Map Matrix membership events to Msgr `channel_member_update` envelopes.

### IRC
1. Establish TCP/TLS connection using `irc-framework` with SASL if credentials are available.
2. Request IRCv3 capabilities: `sasl`, `multi-prefix`, `message-tags`, `server-time` when
   supported.
3. Join configured channels and register listeners for `PRIVMSG`, `NOTICE`, `JOIN`, `PART`,
   `TOPIC`.
4. Emit Msgr membership updates based on server replies (`353`, `366`, `JOIN`, `PART`).

## Failure Handling
- Matrix sync token persistence stored per channel to resume after restarts.
- IRC reconnection with exponential backoff and channel rejoin tracking.
- Bridge daemons publish heartbeat metrics (`bridge.health`) consumed by Msgr monitoring.

## `msgr://` URL Scheme Proposal
The URL scheme allows deep-linking Msgr resources and bridge counterparts.

### Scheme Anatomy
```
msgr://<resource>/<namespace>/<...>
```
- `resource`: high-level category (`channels`, `identity`, `messages`, `bridges`).
- `namespace`: optional segment describing the context (e.g., `msgr`, `matrix`, `irc`).

### Channel References
- **Matrix channel**: `msgr://channels/<workspace>/bridge/matrix/!room:example.org`
- **IRC channel**: `msgr://channels/<workspace>/bridge/irc/irc.libera.chat/%23example`
  - Channels are percent-encoded (`#` → `%23`).

### Identity References
- **Msgr native user**: `msgr://identity/msgr/<user_id>`
- **Matrix user**: `msgr://identity/bridges/matrix/@user:example.org`
- **IRC nickname**: `msgr://identity/bridges/irc/<network>/<nickname>`

### Message References
- **Msgr message**: `msgr://messages/msgr/<conversation_id>/<message_id>`
- **Bridge message**: `msgr://messages/<bridge_id>/<remote_pointer>/<remote_message_id>`
  - Example (Matrix): `msgr://messages/matrix/!room:example.org/$eventid`
  - Example (IRC with `msgid`): `msgr://messages/irc/irc.libera.chat/%23example/abcdef`

### Bridge Configuration Records
- `msgr://bridges/matrix/<workspace>/<room_id>` → Matrix daemon configuration entry.
- `msgr://bridges/irc/<workspace>/<network>/<channel>` → IRC daemon entry.

### Future Extensions
- Append query parameters to express pagination (`?from=<cursor>`), message actions
  (`?action=reply`), or capability lookups (`?capabilities=true`).
- Introduce fragment identifiers for client-side state (e.g., highlight a message:
  `msgr://messages/msgr/<conv>/<msg>#highlight`).

## Next Steps
1. Finalise queue schema fixtures demonstrating Matrix and IRC payloads.
2. Implement bridge daemon skeletons using the shared SDK and configuration records above, ensuring each shard reads from its scoped topic namespace (`bridge/<service>/<bridge_id>/<action>`) so we can stay under per-network connection caps.
3. Add integration tests replaying Matrix `/sync` snapshots and IRC log transcripts to verify
   envelope translation accuracy.
4. Extend the `msgr://` scheme reference as new bridge types and resource categories emerge.

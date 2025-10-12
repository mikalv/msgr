# Matrix, IRC, XMPP, Telegram, and WhatsApp Bridge Blueprint

## Purpose
This document defines the first wave of Msgr bridges, targeting Matrix, IRC, XMPP, Telegram, and
WhatsApp. It covers the minimum viable transport features, queue mappings, and operational
constraints so that
each bridge can move plaintext chat traffic between Msgr and the external networks without media
payload support. The intent is to let Msgr users continue chatting with existing contacts on the
open networks while those communities migrate. The blueprint also introduces a canonical `msgr://`
URL scheme we can reuse to reference channels, identities, bridge resources, and individual
messages across the product.

## Scope Overview
- **Matrix Bridge**: Connects to homeservers via the
  [Matrix Client-Server API](https://spec.matrix.org/latest/client-server-api/), focusing on room
  timelines, membership sync, and typing notifications. File transfer, VoIP, and end-to-end
  encryption are out-of-scope for this initial iteration.
- **IRC Bridge**: Connects to traditional IRC networks using the IRCv3 capability set (SASL,
  tags, message IDs when available). Media payloads are not forwarded; we optionally emit
  placeholder text to preserve context.
- **XMPP Bridge**: Provides a migration path for Msgr users that still rely on legacy XMPP
  accounts. The daemon speaks RFC-compliant XMPP (STARTTLS, SASL, stream management) and focuses on
  roster sync, message relaying, and receipt acknowledgements.
- **Telegram Bridge**: Emulates a full Telegram client over MTProto so Msgr users can talk to
  contacts that have not yet migrated. We prioritise text, entities, and basic media placeholders;
  bot APIs are intentionally avoided to maintain parity with first-party clients.
- **WhatsApp Bridge**: Implements WhatsApp multi-device client emulation (Web socket transport) so
  Msgr accounts can keep chatting with contacts that still rely on Meta's network. We focus on
  login pairing flows, message relay, receipt acknowledgements, and placeholder handling for media.

All five bridges share the Msgr StoneMQ envelope contracts defined in `bridge_architecture.md` and
rely on the Go bridge SDK for queue integration.

## Functional Goals
1. **Message Ingestion**
   - Subscribe to Msgr envelopes and translate them into Matrix events, IRC `PRIVMSG`
     commands, XMPP `<message/>` stanzas, Telegram MTProto `messages.sendMessage` payloads, or
     WhatsApp WebSocket message frames.
   - Collect inbound Matrix timeline events, IRC messages, XMPP stanzas, Telegram updates, and
     WhatsApp events and
     publish them as canonical Msgr envelopes.
2. **Identity Mapping**
   - Maintain a mapping between Msgr identities and remote accounts to enable puppeting or
     relay-style bridging.
   - Support user display name sync (Matrix), nick tracking (IRC), roster presence (XMPP), Telegram
     profile metadata, and WhatsApp profile sync when exposed by the protocol.
3. **Channel Lifecycle**
   - Allow Msgr conversations to attach to Matrix rooms, IRC channels, XMPP chats, or Telegram
     dialogs via bridge
     configuration records.
   - Handle join/part events, membership updates, roster changes, and topic/subject changes (IRC/
     XMPP) to keep the Msgr channel metadata consistent.
4. **Operational Safety**
   - Gate outbound traffic on per-bridge rate limits and connection health metrics.
   - Expose structured logs and metrics to Msgr observability pipelines.

## Non-Goals (MVP)
- Media, voice, and video relaying (provide future hooks for uploading to Msgr media service
  and sending shareable URLs instead).
- Matrix E2EE key management.
- IRC CTCP actions beyond `/me` emotes (supported through message tags only if advertised).
- Telegram secret chats, voice/video calls, or story publishing.
- Threaded replies; all messages are linear until follow-up iteration.

## Architecture Snapshot
```
+----------------------+          +-----------------------+          +----------------------+
|   Msgr StoneMQ       |          |  Matrix Bridge Daemon |          |     Matrix Server    |
|----------------------|          |-----------------------|          |----------------------|
| outbound_message ----|--------->| sendWorker            |--------->| /_matrix/client/v3   |
| inbound_message <----|--------- | timelinePoller        |<---------| Sync/Long Poll       |
| ack_receipt ---------|<---------| ackWorker             |          |                      |
+----------------------+          +-----------------------+          +----------------------+

+----------------------+          +----------------------+           +----------------------+
|   Msgr StoneMQ       |          |    IRC Bridge Daemon |           |       IRC Server     |
|----------------------|          |----------------------|           |----------------------|
| outbound_message ----|--------->| privmsgWorker        |---------->| PRIVMSG              |
| inbound_message <----|--------- | ircListener          |<----------| 353/366 RPL, PRIVMSG |
| ack_receipt ---------|<---------| ackWorker            |           |                      |
+----------------------+          +----------------------+           +----------------------+

+----------------------+          +----------------------+           +----------------------+
|   Msgr StoneMQ       |          |   XMPP Bridge Daemon |           |      XMPP Server     |
|----------------------|          |----------------------|           |----------------------|
| outbound_stanza -----|--------->| stanzaWriter         |---------->| <message/>           |
| inbound_stanza <-----|--------- | xmppStream           |<----------| Stream / MAM         |
| ack_receipt ---------|<---------| receiptWorker        |           |                      |
+----------------------+          +----------------------+           +----------------------+

+----------------------+          +------------------------+         +-----------------------+
|   Msgr StoneMQ       |          | Telegram Bridge Daemon |         |    Telegram Network   |
|----------------------|          |------------------------|         |-----------------------|
| outbound_message ----|--------->| mtprotoSender          |-------->| sendMessage           |
| inbound_update  <----|--------- | mtprotoPoller          |<--------| updates.getDifference |
| ack_update    --------<---------| ackWorker              |         |                       |
+----------------------+          +------------------------+         +-----------------------+
```

## Data Model Contracts
### Msgr Configuration Records
| Field | Matrix | IRC | XMPP | Telegram | WhatsApp | Notes |
|-------|--------|-----|------|----------|----------|-------|
| `bridge_id` | `matrix` | `irc` | `xmpp` | `telegram` | `whatsapp` | Identifies daemon deployment and maps to queue topics (`bridge/<service>/<bridge_id>/<action>`). |
| `channel_ref` | `msgr://channels/<workspace>/bridge/matrix/<room_id>` | `msgr://channels/<workspace>/bridge/irc/<server>/<channel>` | `msgr://channels/<workspace>/bridge/xmpp/<jid>` | `msgr://channels/<workspace>/bridge/telegram/<chat_id>` | `msgr://channels/<workspace>/bridge/whatsapp/<jid>` | Canonical Msgr channel URL. |
| `remote_pointer` | Fully qualified room ID (`!room:server`) | `{network}/{channel}` | Bare/full JID pair | `{dc}/{peer_id}` tuple | WhatsApp JID (`<phone>@s.whatsapp.net`) and device fingerprint | Used when reconnecting or auditing. |
| `puppet_mode` | `relay` or `full` | `relay` | `relay` | `full` (client emulation) | `full` (client emulation) | Telegram starts with user-level puppeting, IRC/XMPP default to relays until per-user sessions are available. |
| `capabilities` | JSON map of supported Matrix feature flags | IRC capability list (e.g., `sasl`, `message-tags`) | Advertised XMPP XEP support (stream management, carbons, MAM) | MTProto feature toggles (premium reactions, story support) | Multi-device flags (history sync, ephemeral keepalive cadence) | Reported by the daemon at runtime. |

### Queue Envelope Payloads
- **Matrix**
  - `outbound_message`: `body`, `formatted_body` (Matrix HTML), `mentions`, optional `reply_to`.
  - `inbound_message`: `remote_id`, `sender_identity`, `timestamp`, `body`, optional `thread_root`.
  - `ack_sync`: `next_batch`, `stream_position` to advance `/sync` tokens.
- **IRC**
  - `outbound_message`: Plaintext `body`, optional `command` overrides for CTCP/NOTICE.
  - `inbound_message`: Deterministic `remote_id` (`msgid` when available), `sender_identity`, `timestamp`, `body`.
  - `ack_offset`: `network`, `channel`, `last_seen` markers so daemons can trim backlog.
- **XMPP**
  - `outbound_stanza`: Serialized XML/JSON stanza, `format`, and routing metadata (`to`, `type`).
  - `inbound_stanza`: `stanza`, `format`, `sender_identity`, `timestamp`, optional MAM `archive_id`.
  - `ack_receipt`: `stanza_id`, `status`, optional `received_at` for precise latency calculations.
- **Telegram**
  - `outbound_message`: `chat_id`, `message`, optional `entities`, `reply_to`, `media` placeholders.
  - `inbound_update`: `update_id`, normalized message payload, optional `media` descriptors.
  - `ack_update`: `update_id`, `status`, `received_at` to let the daemon drop processed updates.
- **WhatsApp**
  - `outbound_message`: `chat_id`, `message`, optional `metadata` map for previews/pins.
  - `inbound_event`: `event_id`, normalized message payload, sender metadata, optional `media` placeholders.
  - `ack_event`: `event_id`, `status`, optional `received_at` timestamps for update cursors.

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

### XMPP
1. Open TCP/TLS stream with STARTTLS negotiation and SASL authentication (PLAIN, SCRAM, or
   EXTERNAL where applicable).
2. Bind a resource according to the configuration payload (`resource`), enable Stream Management
   (XEP-0198), Carbons (XEP-0280), and Message Archive Management (XEP-0313) when supported.
3. Relay `<message/>`, `<presence/>`, and `<iq/>` stanzas between Msgr and the server. The daemon
   persists stanza IDs for receipts and history stitching.
4. Publish roster snapshots and presence updates back to Msgr so contacts appear online/offline in
   the native UI.

### Telegram
1. Perform MTProto device registration using GramJS (or equivalent) seeded with the Msgr credential
   vault session blob. Two-factor challenges are relayed via the `link_account` response channel.
2. Maintain an `updates.getDifference` polling loop per workspace shard to stay in sync with chat
   history and typing indicators.
3. Send outbound messages via `messages.sendMessage`, falling back to placeholders for unsupported
   media kinds. Typing updates leverage `messages.setTyping`.
4. Publish ack envelopes once updates are persisted so the daemon can advance its state cursors and
   free memory.

### WhatsApp
1. Establish a WhatsApp Web multi-device session using the stored pairing blob. If the session is
   missing or expired, request a new QR code and surface it through the `link_account` RPC.
2. Sync chat history via WhatsApp's history sync and patch deltas while streaming real-time events
   over the WebSocket connection.
3. Relay outbound Msgr messages with `sendMessage` frames, respecting per-device rate limits and
   ephemeral setting requirements (disappearing messages stay opt-in).
4. Publish acknowledgement envelopes once events are applied so the daemon can release processed
   update IDs.

## Failure Handling
- Matrix sync token persistence stored per channel to resume after restarts.
- IRC reconnection with exponential backoff and channel rejoin tracking.
- XMPP stream resumption via XEP-0198 and MAM bookmarks so we can avoid message duplication after
  reconnects.
- Telegram update offsets persisted per workspace shard to guard against reprocessing after MTProto
  reconnects.
- WhatsApp pairing blobs rotated automatically when devices unlink; QR requests are rate limited and
  cached per user so we avoid spamming the remote device roster.
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
- **XMPP chat**: `msgr://channels/<workspace>/bridge/xmpp/user@example.org`
- **Telegram chat**: `msgr://channels/<workspace>/bridge/telegram/123456789`
- **WhatsApp chat**: `msgr://channels/<workspace>/bridge/whatsapp/12345@s.whatsapp.net`

### Identity References
- **Msgr native user**: `msgr://identity/msgr/<user_id>`
- **Matrix user**: `msgr://identity/bridges/matrix/@user:example.org`
- **IRC nickname**: `msgr://identity/bridges/irc/<network>/<nickname>`
- **XMPP identity**: `msgr://identity/bridges/xmpp/user@example.org`
- **Telegram user**: `msgr://identity/bridges/telegram/<user_id>`
- **WhatsApp identity**: `msgr://identity/bridges/whatsapp/12345@s.whatsapp.net`

### Message References
- **Msgr message**: `msgr://messages/msgr/<conversation_id>/<message_id>`
- **Bridge message**: `msgr://messages/<bridge_id>/<remote_pointer>/<remote_message_id>`
  - Example (Matrix): `msgr://messages/matrix/!room:example.org/$eventid`
  - Example (IRC with `msgid`): `msgr://messages/irc/irc.libera.chat/%23example/abcdef`
  - Example (XMPP MAM): `msgr://messages/xmpp/user@example.org/1577836800`
  - Example (Telegram): `msgr://messages/telegram/2000000001/512`
  - Example (WhatsApp): `msgr://messages/whatsapp/12345@s.whatsapp.net/A1B2C3`

### Bridge Configuration Records
- `msgr://bridges/matrix/<workspace>/<room_id>` → Matrix daemon configuration entry.
- `msgr://bridges/irc/<workspace>/<network>/<channel>` → IRC daemon entry.
- `msgr://bridges/xmpp/<workspace>/<jid>` → XMPP daemon configuration entry.
- `msgr://bridges/telegram/<workspace>/<chat_id>` → Telegram daemon configuration entry.
- `msgr://bridges/whatsapp/<workspace>/<jid>` → WhatsApp daemon configuration entry.

### Future Extensions
- Append query parameters to express pagination (`?from=<cursor>`), message actions
  (`?action=reply`), or capability lookups (`?capabilities=true`).
- Introduce fragment identifiers for client-side state (e.g., highlight a message:
  `msgr://messages/msgr/<conv>/<msg>#highlight`).

## Next Steps
1. Finalise queue schema fixtures demonstrating Matrix, IRC, XMPP, Telegram, and WhatsApp payloads
   (including MTProto update envelopes, XMPP stanza receipts, and WhatsApp history sync deltas).
2. Implement bridge daemon skeletons using the shared SDK and configuration records above, ensuring
   each shard reads from its scoped topic namespace (`bridge/<service>/<bridge_id>/<action>`) so we
   can stay under per-network connection caps.
3. Add integration tests replaying Matrix `/sync` snapshots, IRC log transcripts, XMPP MAM exports,
   and Telegram update streams to verify envelope translation accuracy.
4. Extend the `msgr://` scheme reference as new bridge types and resource categories emerge
   (including message reactions and media attachments once supported).
5. Prototype Telegram client emulation helpers that can drive GramJS (or a similar MTProto stack)
   alongside a WhatsApp Web multi-device controller using the SDK's per-instance topics, paving the
   way for production-ready sharded deployments.

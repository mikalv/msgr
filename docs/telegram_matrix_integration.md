# Bridge Service Integration Kick-off

## Goals
- Stand up a connector interface that emits intents onto a message queue instead of calling platform HTTP APIs directly.
- Describe the shape of the Telegram, Matrix, IRC, and XMPP envelopes that bridge workers must understand.
- Provide a roadmap for building language-specific daemons that handle the proprietary networking stacks (MTProto, Matrix CS, IRC, XMPP) and communicate with the Elixir core through StoneMQ or compatible brokers.

## Connector Facade
- The Elixir layer creates a `ServiceBridge` per platform and publishes actions to topics such as `bridge/telegram/outbound_message` (or `bridge/telegram/<instance>/outbound_message` when routing to a specific daemon shard).
- Every message carries a deterministic `service`, `action`, `payload`, and `trace_id`, making it straightforward to correlate logs across services.
- Fire-and-forget actions (outbound message, ack) use `publish/4`; control flows (account linking, identity configuration) use `request/4` so we can wait for worker responses.

## Platform Envelopes
- **Telegram**: `link_account` includes `user_id`, `phone_number`, MTProto `session` seed, and `two_factor` hints. `outbound_message` accepts `chat_id`, message content, and optional metadata for formatting or attachments. `ack_update` tells the worker which update IDs have been persisted.
- **Matrix**: `link_account` sends homeserver and login secrets. `outbound_event` provides room ID, event type, JSON content, and optional metadata. `ack_sync` communicates the latest `next_batch` token.
- **IRC**: `configure_identity` provisions SASL/NickServ credentials per network. `outbound_command` wraps raw IRC commands (`PRIVMSG`, `NOTICE`, etc.) with arguments. `ack_offset` announces consumption offsets so the worker can drop buffered backlog.
- **XMPP**: `link_account` includes bare/full JIDs, passwords, and resource binding preferences. `outbound_stanza` transports XML/JSON stanza representations plus routing metadata. `ack_receipt` confirms delivery receipt handling.

## Bridge Daemon Requirements
1. **Queue Adapter**: Implement StoneMQ (or alternative) publishers/subscribers that understand the `bridge/<service>/<action>` topics. When capacity or ToS limits demand deterministic routing, the adapter must also support per-instance channels (`bridge/<service>/<instance>/<action>`). The daemons should reply on deterministic response channels (e.g. `bridge/<service>/<action>/reply/<trace_id>`).
2. **Protocol Engine**: Embed existing libraries (GramJS, mautrix, go-xmpp, or plain IRC clients) to manage network state, reconnects, and encryption.
3. **State Management**: Persist session keys (MTProto auth keys, Matrix access tokens, IRC SASL secrets, XMPP roster state) in the daemon's storage layer, encrypting sensitive data at rest.
4. **Observability**: Propagate the `trace_id` and emit structured logs/metrics so the Elixir supervisor can correlate failures to queue messages.

## Next Steps
1. Prototype StoneMQ bindings for Elixir (publisher/request) and Go (consumer/replier) to validate the queue envelope contract.
2. Generate integration specs per platform that the daemon implementers can follow (handshake transcripts, expected responses, error taxonomy).
3. Extend account linking flows inside Msgr to persist queue-based credentials (e.g. storing Telegram session blobs instead of bot tokens).
4. Build supervision trees that spin up connectors per linked account and subscribe to inbound queues for Telegram, Matrix, IRC, and XMPP events.
5. Codify compliance guidelines for ToS-sensitive networks while prioritising ToS-free systems (IRC/XMPP) for early experiments.

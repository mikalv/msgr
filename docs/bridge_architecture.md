# Bridge Architecture Overview

## Component Map
- **Connector Daemons**: One per external platform, implemented in the language that best matches the reverse-engineered stack (GramJS for Telegram, mautrix for Matrix, plain IRC/XMPP libraries). Each daemon exposes queue handlers for `bridge/<service>/<action>` topics (or `bridge/<service>/<instance>/<action>` when sharded) and translates intents to native protocol calls.
- **Signal REST Adapter**: The Signal bridge now includes a `signal-cli-rest-api` client that polls for envelopes, issues acknowledgements, and relays outbound messages over HTTP while persisting session hints for reboots.
- **Elixir Connector Facade**: The Msgr backend uses `ServiceBridge` helpers to build deterministic envelopes and publish them to the queue. Incoming events are normalised and persisted in Postgres before fanning out to clients.
- **Message Fabric**: StoneMQ (or a compatible broker) provides pub/sub plus request/response semantics. We reserve namespaces per tenant and service to guarantee isolation and allow selective replay.
- **Impersonation & Policy Layer**: Holds outbound routing logic, resolves which linked identity to impersonate, injects credentials, and enforces workspace policy before publishing intents.
- **Credential Vault**: Hardware-backed store (HSM/YubiHSM or cloud KMS) for OAuth tokens, MTProto keys, Matrix access tokens, IRC SASL secrets, etc. The Elixir app checks out short-lived session material that the daemons can refresh when needed.
- **Compliance & Audit**: Centralised OpenTelemetry pipeline with append-only audit store capturing the original queue envelope, trace IDs, and daemon responses.

## Data Flow
1. **Inbound Messages**
   - Daemon receives network traffic → emits canonical events to `bridge/<service>/inbound_event`
     (or `bridge/<service>/<instance>/inbound_event` when reporting from a sharded worker). Service
     implementations fan these out as `inbound_message` (Matrix/IRC), `inbound_stanza` (XMPP), or
     `inbound_update` (Telegram) envelopes depending on the protocol.
   - Elixir subscribers normalise the payload, persist it, and schedule ack messages such as
     `ack_update`, `ack_sync`, `ack_offset`, or `ack_receipt`.
2. **Outbound Messages**
   - Clients send a message → backend records intent → publishes an outbound envelope
     (`outbound_message`, `outbound_event`, `outbound_stanza`, etc.). The `ServiceBridge` helper
     optionally scopes the topic to a daemon instance (`bridge/<service>/<instance>/<action>`) when
     we need to target a specific shard.
   - Daemon delivers the message using the platform protocol, then emits delivery status or errors referencing the original `trace_id`.
3. **State Synchronisation**
   - Workers trigger periodic sync actions (`request_history`, `refresh_roster`) over the queue.
   - Daemons stream results and update tokens; Elixir writes checkpoints and notifies subscribers.

## Service Action Map
| Service  | Outbound Actions                                   | Inbound Actions                     | Ack/Control Actions                  |
|----------|----------------------------------------------------|-------------------------------------|--------------------------------------|
| Matrix   | `outbound_message`, `outbound_event`, `typing`      | `inbound_message`, membership feeds | `ack_sync`, `link_account` replies   |
| IRC      | `outbound_message`, `outbound_command`             | `inbound_message`, `membership`     | `ack_offset`, `configure_identity`   |
| XMPP     | `outbound_stanza`, `presence_update`               | `inbound_stanza`, roster snapshots  | `ack_receipt`, `link_account`        |
| Telegram | `outbound_message`, `typing_update`, `media_stub`  | `inbound_update`, `state_update`    | `ack_update`, `link_account`         |
| WhatsApp | `outbound_message`, `typing_placeholder`           | `inbound_event`, `state_update`     | `ack_event`, `link_account`          |
| Signal   | `outbound_message`, `profile_sync`                 | `inbound_event`, `receipt_update`   | `ack_event`, `link_account`          |
| Snapchat | `outbound_message` *(skeleton)*                    | _pending client implementation_     | `link_account` *(not implemented)*   |

The table captures the canonical actions our queue contracts use per service. Each bridge daemon
implements a subset tailored to the network's capabilities and gradually expands coverage as new
features land (e.g., Telegram media uploads, XMPP MAM export streaming).

## Conversation History Streaming
- Clients request historical windows by pushing `message:sync` on the Phoenix conversation channel.
- The backend serves cursor-based pages (before/after/around IDs) and rebroadcasts the backlog via PubSub so every watcher receives the same slice.
- REST controllers expose the same pagination contract, including `unread_count`, `last_message`, and watcher counts per conversation.
- `conversation:watch` / `conversation:unwatch` maintain lightweight ETS-backed presence lists that surface active viewers to all subscribers.

## Security Layers
- Per-daemon containers with AppArmor/seccomp profiles to contain native libraries and reverse-engineered code.
- Mutual TLS (or Noise handshakes) between daemons and StoneMQ plus signed envelopes verified by the Elixir core.
- Scoped credentials per workspace identity; queue consumers require explicit capability grants (send, sync, admin).
- Policy enforcement before publishing outbound intents to guard against DLP violations and cross-tenant leakage.

## Scalability Considerations
- Horizontal scale by spinning up daemon shards per workspace or region. Shards can subscribe as competing consumers on `bridge/<service>/<action>` or, when connection caps require deterministic routing, use per-instance topics (`bridge/<service>/<instance>/<action>`) so the Elixir layer can steer traffic to specific deployments.
- Rate limiting implemented at the daemon level to respect platform-specific quotas, with back-pressure fed to Elixir through `throttle` events.
- Idempotent processing using platform message IDs combined with Msgr `trace_id`s to deduplicate retries.
- Replay buffers (StoneMQ durable topics) allow catch-up after outages without losing handshake state.

## Observability
- Metrics: queue depth, daemon reconnect counts, latency per action, handshake success/failure tallies.
- Tracing: propagate the queue `trace_id` into daemon spans so distributed traces cover Elixir + external protocol hops.
- Alerting: thresholds on sync lag, credential expiry windows, abnormal rejection rates on outbound intents.

## Developer Experience
- Provide local StoneMQ docker-compose stack with fake daemons that echo payloads for contract testing.
- Contract tests validate canonical schema compatibility per service (Telegram, Matrix, IRC, XMPP) using the `ServiceBridge` envelope definitions.
- Feature flags gate platform rollout so operators can enable connectors per workspace gradually.

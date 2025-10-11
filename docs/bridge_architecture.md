# Bridge Architecture Overview

## Component Map
- **Connector Daemons**: One per external platform, implemented in the language that best matches the reverse-engineered stack (GramJS for Telegram, mautrix for Matrix, plain IRC/XMPP libraries). Each daemon exposes queue handlers for `bridge/<service>/<action>` topics and translates intents to native protocol calls.
- **Elixir Connector Facade**: The Msgr backend uses `ServiceBridge` helpers to build deterministic envelopes and publish them to the queue. Incoming events are normalised and persisted in Postgres before fanning out to clients.
- **Message Fabric**: StoneMQ (or a compatible broker) provides pub/sub plus request/response semantics. We reserve namespaces per tenant and service to guarantee isolation and allow selective replay.
- **Impersonation & Policy Layer**: Holds outbound routing logic, resolves which linked identity to impersonate, injects credentials, and enforces workspace policy before publishing intents.
- **Credential Vault**: Hardware-backed store (HSM/YubiHSM or cloud KMS) for OAuth tokens, MTProto keys, Matrix access tokens, IRC SASL secrets, etc. The Elixir app checks out short-lived session material that the daemons can refresh when needed.
- **Compliance & Audit**: Centralised OpenTelemetry pipeline with append-only audit store capturing the original queue envelope, trace IDs, and daemon responses.

## Data Flow
1. **Inbound Messages**
   - Daemon receives network traffic → emits canonical events to `bridge/<service>/inbound_event` (or service-specific topics).
   - Elixir subscribers normalise the payload, persist it, and schedule ack messages such as `ack_update`, `ack_sync`, or `ack_offset`.
2. **Outbound Messages**
   - Clients send a message → backend records intent → publishes an outbound envelope (`outbound_message`, `outbound_event`, etc.).
   - Daemon delivers the message using the platform protocol, then emits delivery status or errors referencing the original `trace_id`.
3. **State Synchronisation**
   - Workers trigger periodic sync actions (`request_history`, `refresh_roster`) over the queue.
   - Daemons stream results and update tokens; Elixir writes checkpoints and notifies subscribers.

## Security Layers
- Per-daemon containers with AppArmor/seccomp profiles to contain native libraries and reverse-engineered code.
- Mutual TLS (or Noise handshakes) between daemons and StoneMQ plus signed envelopes verified by the Elixir core.
- Scoped credentials per workspace identity; queue consumers require explicit capability grants (send, sync, admin).
- Policy enforcement before publishing outbound intents to guard against DLP violations and cross-tenant leakage.

## Scalability Considerations
- Horizontal scale by spinning up daemon shards per workspace or region; shards subscribe to the same topics with competing consumers.
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

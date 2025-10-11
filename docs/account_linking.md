# Account Linking and Identity Management

## Linking Workflow
1. **User Initiation**: User selects target platform (Telegram, Matrix, IRC, XMPP, Slack/Discord follow-ups) from Msgr UI.
2. **Authentication Step**:
   - Telegram: Generate device login via MTProto bridge daemon (QR or SMS code) by publishing a `link_account` request. Worker handles API ID/hash and returns encrypted session blob.
   - Matrix: Delegate password/SSO login to the daemon which returns access token + device ID over the queue.
   - IRC: Collect nickname + SASL/NickServ secrets and send `configure_identity` so the daemon can negotiate with the network.
   - XMPP: Capture JID, password, resource preferences; worker binds the resource and confirms roster sync readiness.
3. **Credential Storage**: Encrypted session material (MTProto auth key, Matrix token, IRC SASL secret, XMPP password) stored in the Credential Vault. Only opaque references are shared with daemons.
4. **Verification**: Msgr waits for queue responses that include capability summaries (channels joined, roster count, network modes). Failed verifications surface actionable errors to the user.
5. **Policy Binding**: Policy engine maps returned capabilities to Msgr permission scopes (e.g., allow outbound Telegram message send, read-only IRC channels).
6. **Activation**: Supervisor spins up per-account connector processes that subscribe to inbound queue topics and publish ack messages once events are persisted.

## Identity Representation
- **Msgr Account**: Primary identity with multiple profiles (Jobb/Privat). Each profile may link to several external personas handled by daemons.
- **Persona Descriptor**: JSON structure storing platform, daemon shard, external identifiers, available capabilities, and last refresh timestamp.
- **Impersonation Ticket**: Short-lived signed blob referencing the persona descriptor. Used when emitting outbound intents so the daemon knows which credentials to attach.

## Consent & Transparency
- UI lists all queue actions the daemon will perform (read history, send messages, manage presence).
- Audit trail records every linking attempt, queue response, and impersonated send keyed by `trace_id`.
- Users can pause/revoke connectors; revocation emits a `disconnect` intent that instructs daemons to drop sessions immediately.

## Security Controls
- MFA required before linking high-risk platforms or enabling outbound send.
- Queue responses include attested fingerprint of the daemon build so Msgr can refuse outdated binaries.
- Secrets encrypted with per-user keys stored in HSM/KMS; daemons receive scoped credentials using envelope encryption.
- Optional "confirm first send" flow for each connector to avoid accidental impersonation.

## Data Residency & Compliance
- Ensure queue brokers and credential vaults respect tenant residency requirements (EU-only deployments where needed).
- Retain original platform message IDs, offsets, and roster snapshots for legal hold exports.
- Honour remote deletion/retention policies by forwarding daemon-originated `delete`/`redact` events into the policy layer.

## Failure Handling
- Detect queue timeouts or negative acknowledgements and prompt user to relink.
- Retry outbound messages with exponential backoff; demote to read-only when repeated failures occur.
- Surface degraded mode indicators in UI when daemon reports limited capabilities (e.g., IRC network under netsplit).

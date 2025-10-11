# Account Linking and Identity Management

## Linking Workflow
1. **User Initiation**: User selects target platform (Slack, Telegram, Discord, Matrix, XMPP) from Msgr UI.
2. **Authentication Step**:
   - Slack/Discord: OAuth 2.0 flow with requested scopes (`channels:read`, `chat:write`, etc.).
   - Telegram: QR code login to official client or manual entry of phone code; optionally require user-supplied API ID/hash for MTProto sessions.
   - Matrix: Client login using homeserver credentials or delegated login via application service registration.
   - XMPP: Username/password or SASL/OAuth depending on server; support SRV discovery.
3. **Credential Storage**: Tokens sealed in Credential Vault, encrypted per user profile with hardware-backed master keys.
4. **Verification**: Connector performs validation ping (fetch profile, list channels) to confirm permissions.
5. **Policy Binding**: Msgr policy engine associates connector capabilities with user profile (e.g., allow send in specific workspaces).
6. **Activation**: User selects mapping rules (e.g., Slack `#general` → Msgr Jobb workspace).

## Identity Representation
- **Msgr Account**: Primary identity with multiple profiles (Jobb/Privat). Each profile may link to multiple external personas.
- **Persona Descriptor**: JSON object storing platform, external user id, display name, avatar hash, scope list, last refresh timestamp.
- **Impersonation Token**: Short-lived signed assertion referencing persona descriptor, used by Impersonation Service to act on behalf of user.

## Consent & Transparency
- UI surfaces clear explanation of actions performed (read, send, delete).
- Provide audit trail showing who linked an account, when tokens were refreshed, and every impersonated send.
- Allow users to pause or revoke connector access instantly.

## Security Controls
- MFA required before linking high-risk platforms (Slack Enterprise, corporate Discord servers).
- Automatic detection of credential anomalies (location change, repeated failures) triggering re-authentication.
- Scoped least-privilege tokens; refresh tokens stored only in vault, access tokens short-lived and rotated.
- Optional per-message confirmation for first-time sends in each channel to avoid accidental impersonation.

## Data Residency & Compliance
- Respect platform-specific data handling rules; ensure storage within EU jurisdictions if required.
- Support legal hold export for enterprise customers (retain original platform message IDs and metadata).
- Provide mechanisms to honour remote deletion requests (e.g., Slack message deletion mirrored back to Msgr).

## Failure Handling
- Detect revoked tokens and surface actionable UI prompts.
- Provide queued outbound messages with retry/backoff; notify user if message ultimately fails to deliver.
- Fallback read-only mode when impersonation fails, maintaining inbound visibility.

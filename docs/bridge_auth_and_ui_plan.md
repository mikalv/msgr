# Bridge Authentication and Client Experience Plan

## Objectives
- Provide a unified login and configuration experience for all bridge connectors.
- Support OAuth/OIDC and other interactive flows that require an embedded browser surface inside the Msgr client.
- Ensure the backend and daemon layers can manage tokens securely while keeping the client experience responsive and transparent.
- Prepare for future scale challenges where bridge traffic density risks IP bans by enabling optional self-hosted egress paths.

## Implementation Status (October 2024)
- ✅ **Backend catalog & auth session scaffolding** – `/api/bridges/catalog` and `/api/bridges/:id/sessions` now exist with a
  static connector catalog, session persistence, and JSON renderers.
- ✅ **OAuth/OIDC relay endpoints** – Browser bootstrap/callback endpoints (`/auth/bridge/:session_id/*`) now issue PKCE
  state, use a mock provider for development, and persist credential references via the in-memory vault to unblock client
  integrations.
- ✅ **Non-OAuth credential hand-off** – Password/device credential submissions land in an ETS-backed inbox with field-level
  summaries stored on the session metadata so daemons can dequeue secrets without exposing them to the client.
- ⚠️ **Daemon progress events** – Websocket push events, StoneMQ job signalling, and observability hooks are still TODO.
- ✅ **Client UX (phase 1)** – Flutter client now ships a bridge catalog, filterable settings entry, and a multi-step wizard with embedded browser, credential forms, and status polling hooks. Websocket listeners and analytics remain TODO.
- ⚠️ **Self-hosted/tunnel egress** – Both future IP mitigation options require design/implementation work and documentation.

## Guiding Principles
1. **Security First** – Bridge login flows must never expose raw credentials to the Msgr client. Use PKCE/OIDC or delegated token exchange wherever possible and vault all secrets server-side.
2. **Progressive Disclosure** – Keep the default UI simple (bridge list, statuses, quick actions) while offering an "Advanced" path for power users (custom endpoints, self-hosted daemons).
3. **Consistency Across Bridges** – Reuse a wizard shell and state machine for all connectors so users learn the pattern once.
4. **Observability & Recovery** – Every login/config step emits events that drive operator dashboards, retries, and self-healing flows.

## Login Flow Architecture
1. **Bridge Catalog Fetch**
   - Client calls `/api/bridges/catalog` which returns available connectors, required capabilities, and login method metadata (`oauth`, `qr_code`, `password`, `device_link`).
   - Catalog payload includes `auth_surface` hints (`embedded_browser`, `native_form`, `external_device`) and prerequisites (e.g., "needs bot token").

2. **Auth Session Bootstrap**
   - When a user chooses a bridge, client POSTs to `/api/bridges/:id/sessions`.
   - Backend creates a `bridge_auth_session` record with state machine: `initiated → awaiting_user → completing → linked`.
   - Response tells the client whether to open an embedded browser (via platform webview), show a native form (username/password), or poll for device link codes.

3. **Embedded Browser Handling (OAuth/OIDC)**
   - Client opens an in-app browser pointing to backend `/auth/bridge/:session_id/start`.
   - Backend proxies to external OAuth/OIDC login with PKCE; callback terminates at `/auth/bridge/:session_id/callback`.
   - Once tokens exchanged, backend stores refresh/access tokens in Credential Vault and returns `completing` state.
   - Client closes the browser when it receives `auth_complete` websocket event or via redirect to a custom URL scheme (`msgr://bridge-auth-complete/:session_id`).

4. **Credential Submission (Non-OAuth)**
   - For bridges needing username/password, bots, or certificates, client renders native forms based on schema returned in catalog (fields, validation rules).
   - Submissions go through `/api/bridges/:id/sessions/:session_id/credentials`; backend immediately scrubs secrets after handing them to the daemon via secure queue.
   - Session state transitions to `completing`, with progress updates pushed over websockets.

5. **Daemon Confirmation**
   - Daemon picks up `link_account` job, completes login, and emits `link_account:success` or `link_account:error` to StoneMQ.
   - Backend updates session state and notifies client via Phoenix channel so UI can show success/failure.

6. **Post-Link Configuration**
   - After success, client transitions user into a configuration wizard (channels to sync, message direction, notification preferences).
   - Backend persists per-bridge settings in `bridge_accounts` table, sharding events to correct daemon instance.

## UI/UX Plan
1. **Bridge List View**
   - Entry in settings named "Connected Bridges" showing cards for each available connector.
   - Card displays logo, short description, status badge (`Not Linked`, `Linked`, `Error`, `Expired`), and CTA (`Connect`, `Manage`).
   - Filtering tabs for `Available`, `Linked`, `Coming Soon` sourced from catalog payload.

2. **Connection Wizard**
   - Stepper: `Overview → Authentication → Permissions → Finalise`.
   - Shared wizard shell with dynamic components depending on auth type:
     - OAuth/OIDC: show embedded browser container with loading indicator and fallback instructions.
     - Device Link: show code, timer, and success detection using websocket events.
     - Manual Credentials: render dynamic form schema with password vault hinting.
   - Include progress log panel showing daemon events ("Waiting for Telegram to confirm…").

3. **Management Screen**
   - For linked bridges, show configuration tabs: `Status`, `Sync Rules`, `Advanced`.
   - `Status` tab includes last sync timestamp, account identity preview, and reauth button.
   - `Sync Rules` surfaces toggles for conversation inclusion, directionality (read-only, two-way), and mention filters.
   - `Advanced` exposes endpoint overrides, custom self-hosted daemon selection, and diagnostic tools (log download, restart).

4. **Error & Expiry Handling**
   - When tokens expire, backend emits `reauth_required`; client shows inline alert with `Reauthenticate` button that relaunches the wizard at the auth step.
   - Errors include actionable messages with retry/backoff, and logs are linkable for support.

5. **Accessibility Considerations**
   - Ensure embedded browser surfaces are keyboard navigable with clear focus management.
   - Provide textual alternatives for QR codes/device codes.
   - Respect platform theming (dark mode) in wizard components.

## Backend & Daemon Requirements
- Extend queue contracts with `link_account`, `reauthenticate`, and `configure_bridge` actions per connector.
- Store auth session states with TTL cleanup; include audit trail of transitions for compliance.
- Integrate Credential Vault with per-bridge scopes; rotate refresh tokens where supported.
- Provide webhook or push events to inform clients of long-running steps (e.g., waiting on user to approve device code).
- Add rate limiting guardrails to prevent repeated failed login attempts from locking accounts.

## Client Implementation Checklist
1. Implement catalog fetch + caching in settings store.
2. Build bridge list UI with skeleton loading states.
3. Create wizard components, leveraging shared state machine for steps.
4. Integrate embedded browser/webview wrapper with callback handler.
5. Implement websocket listener for auth session updates.
6. Persist per-bridge preferences locally and sync with backend on change.
7. Add analytics events for step completion/failure to measure funnel drop-off.

## Source IP Scalability Strategy (Future Work)
### Problem Statement
High bridge adoption may concentrate hundreds of connections per daemon IP, triggering rate limits or outright bans from external chat networks.

### Option 1 – User-Hosted Bridge Daemon
- Provide downloadable daemon package (container and systemd unit) that users can run on personal infrastructure.
- Msgr backend registers the daemon via secure mutual TLS; clients can select "Use self-hosted daemon" in the wizard Advanced tab.
- Pros: Offloads connection count to user-controlled IPs, enhances privacy.
- Cons: Requires setup expertise; support burden for misconfigured environments.
- TODOs:
  - Publish deployment guide + auto-updater.
  - Allow workspace-level provisioning tokens to pair daemon with Msgr.
  - Add health reporting (heartbeat, metrics) so Msgr can detect offline daemons.

### Option 2 – Client-Tunneled Bridge Traffic
- Leverage Msgr client as egress proxy: daemon connections terminate at client, which forwards traffic to external networks.
- Implementation sketch:
  - Establish secure channel (Noise/WebRTC data channel) between daemon and client.
  - Client maintains outbound connections using user IP; daemon logic runs in Msgr infrastructure.
- Pros: Zero extra setup for users.
- Cons: Doubles client bandwidth, depends on client uptime, complex NAT traversal, mobile battery impact.
- TODOs:
  - Prototype tunnelling layer to measure latency/bandwidth costs.
  - Implement adaptive fallback to infrastructure IPs when client offline.
  - Investigate regulatory implications of routing third-party traffic through end-user devices.

### Decision Framework
- Default to infrastructure-hosted daemons while bridge density is manageable.
- Monitor per-bridge IP bans/blocks; when thresholds crossed, prioritise development of Option 1 with Option 2 as fallback for mobile-first users who cannot self-host.
- Design auth wizard to allow migrating existing bridge accounts between hosting modes with minimal downtime.

## Milestones & Next Steps
1. Finalise API schemas for catalog and auth session endpoints (backend ticket).
2. Build client wizard scaffolding and embedded browser integration.
3. Prototype OAuth flow with Telegram/Matrix connectors end-to-end.
4. Add daemon support for reporting detailed auth progress.
5. Document self-hosted daemon requirements and begin spike on secure registration.
6. Evaluate tunnelling feasibility once bridge adoption metrics justify the investment.


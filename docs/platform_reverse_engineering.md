# Platform-Specific Notes

## Slack
- Prefer official APIs: Events API, RTM websocket, Web API for send/edit/delete.
- For impersonation beyond bot capabilities, leverage user-level OAuth tokens with `users:read`, `im:write` scopes.
- Reverse engineering fallback: capture Slack desktop client traffic to document undocumented endpoints (e.g., presence, threads). Keep isolated and optional.
- Maintain compatibility matrix by workspace tier (Free, Pro, Enterprise Grid).

## Telegram
- Combine Bot API for public channels with MTProto user sessions for impersonation in private chats.
- Reverse engineer login flow via Telethon/gramJS references; store session files securely.
- Study MTProto message types for reactions, polls, replies to ensure parity.
- Respect Telegram's flood wait rules; implement adaptive delays.

## Discord
- Start with bot accounts using Gateway v10 for ingestion.
- For user impersonation, research client RPCs (open-source projects like Powercord as references) but keep behind legal review.
- Implement voice/state sync as separate module (future scope).
- Watch for anti-bot detection (fingerprinting, TLS fingerprints) when mimicking official clients.

## Matrix
- Use official Client-Server API; bridging facilitated through Application Service registration.
- Implement sync loop with incremental tokens, timeline filters.
- Support end-to-end encryption by running Olm/Megolm session management in connector or delegating to Msgr core.

## XMPP
- Implement RFC-compliant XMPP client with SASL auth, Stream Management (XEP-0198), MAM (XEP-0313), and Carbon (XEP-0280).
- Provide gateway for custom server features (e.g., Slack-style channels via MUC).
- Evaluate use of existing libraries (e.g., `stanza`, `slixmpp`) as base.

## Cross-Cutting Tasks
- Create protocol test harness capturing network traces and verifying message parity with official clients.
- Maintain dossier per platform summarising ToS clauses affecting impersonation/automation.
- Establish update monitoring: subscribe to changelog feeds/webhooks to detect API changes early.

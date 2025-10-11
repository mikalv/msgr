# Platform-Specific Notes

## Slack
- Prefer official APIs: Events API, RTM websocket, Web API for send/edit/delete.
- For impersonation beyond bot capabilities, leverage user-level OAuth tokens with `users:read`, `im:write` scopes.
- Reverse engineering fallback: capture Slack desktop client traffic to document undocumented endpoints (presence, threads). Keep isolated and optional.
- Maintain compatibility matrix by workspace tier (Free, Pro, Enterprise Grid).

## Telegram
- Focus on MTProto user sessions exclusively; avoid Bot API limitations.
- Reuse open-source clients (GramJS, MadelineProto, Telethon) as references for auth key generation, device registration, and CDN downloads.
- Document flood-wait penalties, DC migrations, and file upload chunking to inform daemon retry/backoff logic.
- Capture schema updates (TL definitions) automatically so bridge daemons stay compatible.

## Discord
- Start with bot accounts using Gateway v10 for ingestion.
- For user impersonation, research client RPCs (open-source projects like Powercord as references) but keep behind legal review.
- Implement voice/state sync as separate module (future scope).
- Watch for anti-bot detection (fingerprinting, TLS fingerprints) when mimicking official clients.

## Matrix
- Use Client-Server API through custom daemon so we can run olm/megolm state outside the Elixir VM.
- Implement sync loop with incremental tokens, timeline filters, and to-device message handling.
- Support end-to-end encryption by managing Olm/Megolm sessions inside the daemon and exposing decrypted payloads to Msgr.

## IRC
- Target plain TCP (or TLS) connections with SASL, NickServ, and modern extensions (capability negotiation, message tags).
- Handle netsplit recovery and backlog replay; integrate ZNC-style playback when available.
- Provide mapping for server numerics to canonical Msgr event types.

## XMPP
- Implement RFC-compliant XMPP client with SASL auth, Stream Management (XEP-0198), MAM (XEP-0313), and Carbon (XEP-0280).
- Provide gateway for custom server features (Slack-style channels via MUC, push notifications via PubSub).
- Evaluate existing libraries (`slixmpp`, `aioxmpp`, `stanza`) and wrap them in the queue worker to keep Elixir thin.

## Cross-Cutting Tasks
- Create protocol test harness capturing network traces and verifying message parity with official clients.
- Maintain dossier per platform summarising ToS clauses affecting impersonation/automation.
- Establish update monitoring: subscribe to changelog feeds/webhooks to detect API changes early.

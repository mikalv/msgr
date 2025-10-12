# Bridge Implementation Status

This document summarises what exists in the repository for each chat bridge and what remains
before we can run them against the real networks.

## Bridge Data Store
- **Code status**: A new `Messngr.Bridges` context persists bridge identities, reported capabilities,
  contact rosters, and channel/group memberships in PostgreSQL via the `bridge_accounts`,
  `bridge_contacts`, and `bridge_channels` tables. Telegram and Signal connectors synchronise
  their daemon responses into this store so the core backend understands what features are
  available per account.
- **Missing work**: Wire the store into Matrix/IRC/XMPP once their daemons land, add retention and
  reconciliation jobs, and expose capability summaries to the product surface.
- **Operational blockers**: Schema migrations must be applied before linking accounts; operators
  should provision adequate disk space for per-user contact/channel snapshots.

## Matrix & IRC
- **Code status**: Only planning material exists in `docs/matrix_irc_bridge_blueprint.md`; there are
  no daemon packages or protocol adapters in `bridge_sdks`. The queue helpers in the Go SDK are the
  only reusable pieces today.
- **Missing work**: Implement actual Matrix and IRC client daemons (probably via mautrix/mautrix-go
  or irc libraries), wire them to StoneMQ, and add persistence plus configuration plumbing.
- **Operational blockers**: Without the daemons we cannot authenticate, join rooms/channels, or relay
  traffic.

## XMPP
- **Code status**: Like Matrix/IRC, there is no XMPP bridge package in the repo; the blueprint merely
  outlines the desired behaviour.
- **Missing work**: Build a full XMPP client daemon with roster sync, message relay, and ack support,
  handle credential storage, and add queue integration tests.
- **Operational blockers**: No code exists to log into or speak the XMPP protocol yet.

## Telegram
- **Code status**: The MTProto daemon in `bridge_sdks/python/msgr_telegram_bridge` now records
  message identifiers, issues Telethon read acknowledgements when the backend publishes
  `ack_update`, supports outbound edits/deletions, normalises inbound updates, and advertises
  capabilities plus contact/channel snapshots during the link handshake. Login, session
  persistence, outbound messaging, and inbound update forwarding are implemented.
- **Missing work**: Flesh out rich media uploads (videos/documents), test acknowledgements against
  channels/supergroups, and exercise the Telethon adapter with live integration tests plus runtime
  configuration management.
- **Operational blockers**: Requires Telethon dependencies and API credentials; media uploads beyond
  inline photos/files are still deferred.

## WhatsApp
- **Code status**: Only protocol interfaces and session helpers exist in
  `bridge_sdks/python/msgr_whatsapp_bridge`; there is no concrete client that speaks WhatsApp's
  Web socket protocol.
- **Missing work**: Implement the multi-device client (e.g. based on open-source reverse-engineered
  stacks such as yowsup/signal's libsignal), handle QR pairing, message encryption/decryption, and
  media placeholders.
- **Operational blockers**: Without a real client implementation the daemon cannot pair or send any
  WhatsApp traffic.

- **Code status**: The bridge now ships with a REST client that targets `signal-cli-rest-api`,
  handling account linking, outbound messaging with attachment uploads, inbound polling, and
  acknowledgement cleanup while persisting session hints to disk. The daemon also reports
  capabilities and cached contacts/conversation identifiers so the backend can populate the
  Postgres bridge store.
- **Missing work**: Harden the REST client with streaming uploads for large media, error
  retry/backoff, device slot management, and end-to-end integration tests against a running
  `signal-cli` deployment.
- **Operational blockers**: Operators must deploy and secure the REST API, provision device slots,
  and feed credentials before the bridge can join the real network.

## Snapchat
- **Code status**: A queue-facing skeleton exists in `bridge_sdks/python/msgr_snapchat_bridge` that
  captures intents and exposes session helpers, but it intentionally responds with
  `not_implemented` payloads until a real client lands.
- **Missing work**: Reverse-engineer or obtain official Snapchat messaging APIs, implement the
  client protocol, and wire media/conversation semantics before the bridge can deliver traffic.
- **Operational blockers**: Snapchat does not expose an officially supported API for multi-device
  chat, so the skeleton cannot progress without further research and credential bootstrapping.


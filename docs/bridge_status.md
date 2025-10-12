# Bridge Implementation Status

This document summarises what exists in the repository for each chat bridge and what remains
before we can run them against the real networks.

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
- **Code status**: There is an MTProto-aware daemon in `bridge_sdks/python/msgr_telegram_bridge` that
  wraps Telethon. Login, session persistence, outbound messaging, and inbound update forwarding are
  implemented, but ack handling is currently a no-op and we still lack coverage for media/file
  transfer flows.
- **Missing work**: Implement read-receipt tracking for `ack_update`, flesh out media handling, and
  exercise the Telethon adapter with live integration tests plus runtime configuration management.
- **Operational blockers**: Requires Telethon dependencies and API credentials; until ack/media gaps
  are closed we risk message duplication or missing content.

## WhatsApp
- **Code status**: Only protocol interfaces and session helpers exist in
  `bridge_sdks/python/msgr_whatsapp_bridge`; there is no concrete client that speaks WhatsApp's
  Web socket protocol.
- **Missing work**: Implement the multi-device client (e.g. based on open-source reverse-engineered
  stacks such as yowsup/signal's libsignal), handle QR pairing, message encryption/decryption, and
  media placeholders.
- **Operational blockers**: Without a real client implementation the daemon cannot pair or send any
  WhatsApp traffic.

## Signal
- **Code status**: The bridge daemon coordinates queue handlers and session persistence, but the
  `SignalClientProtocol` is only defined as an interface—there is no implementation wired to a
  libsignal client.
- **Missing work**: Provide an actual Signal client adapter (linking, sending, event streaming),
  manage device slots/rate limits, and add integration tests against the Signal service.
- **Operational blockers**: Lacking the client implementation prevents linking devices or relaying
  traffic.


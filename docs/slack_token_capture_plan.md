# Slack Embedded Browser Token Capture Plan

Slack's RTM websocket expects the same authenticated cookies and API tokens that the
first-party client negotiates. Because workspace admins frequently disable classic
OAuth flows, we need a puppeting strategy that works with end-user credentials.
The recommended approach is to drive an embedded browser inside Msgr, intercept
the Slack web client's websocket bootstrap, and surface the resulting `xoxs`/`xoxp`
token to the bridge daemon.

## Goals

* Support user-level Slack bridges without depending on bot tokens.
* Avoid storing raw credentials—only persist the generated RTM token.
* Keep the flow auditable and repeatable so support can troubleshoot failed installs.

## Flow Overview

1. **Launch Trusted WebView** – Open an embedded browser targeting
   `https://slack.com/signin`. The webview must expose hooks for network events.
2. **User Authentication** – Let the user complete any SSO/MFA prompts.
3. **Capture RTM Bootstrap** – Listen for websocket connections against the
   Slack RTM bootstrap endpoints. Libraries such as
   [`SlackStream`](https://github.com/mazun/SlackStream) demonstrate how the
   browser session upgrades to the RTM socket and carries the final token.
4. **Extract Token** – Parse the websocket upgrade payload (or the accompanying
   `xoxs` cookie) and package it as `{ token: "xoxs-...", token_type: "user" }`.
5. **Secure Storage** – Encrypt the token using Msgr's credential vault (same
   machinery used for Telegram/WhatsApp session files) and hand the encrypted
   blob to the bridge daemon via the `session` payload.
6. **Daemon Startup** – The Slack bridge daemon now connects to Slack using the
   captured token and rehydrates workspace/user state.

## Security Considerations

* Tokens should never be logged—mask the value in telemetry and traces.
* Always expire stored tokens when the user unlinks the workspace.
* Use a dedicated process sandbox for the embedded browser to limit exposure.

## References

* [haringsrob/CollabApp](https://github.com/haringsrob/CollabApp) – example of
  driving Slack in an embedded browser.
* [mazun/SlackStream](https://github.com/mazun/SlackStream) – shows how to
  intercept Slack's websocket handshake and decode messages.

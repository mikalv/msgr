# Bridge Integration Execution Plan

## Purpose
This plan translates the bridge research notes into a concrete execution strategy for wiring Msgr's queue-based bridge layer to multiple external chat ecosystems. It aligns with the bridge architecture and strategy documents by detailing the reverse-engineering (RE) passes, base projects, and delivery milestones per network family.

## Methodology
1. **Foundation Alignment (Week 0)**
   - Finalise the StoneMQ envelope contract and Elixir `ServiceBridge` helpers described in the architecture and strategy references.
   - Stand up a shared bridge SDK skeleton (Go/Python) covering queue subscriptions, envelope parsing, telemetry, and credential bootstrap.
2. **Reverse Engineering Rounds**
   - **RE Round A (Weeks 1-2)**: Capture protocol handshakes, auth flows, and rate limits using reference clients or MITM proxies. Focus on metadata fields required for puppeting (avatars, display names, thread identifiers).
   - **RE Round B (Weeks 3-4)**: Validate automation edge cases (edits, reactions, attachments) and permission scopes. Feed results into contract tests and queue schema fixtures.
3. **Bridge Hardening (Ongoing)**
   - Add compliance guardrails (ToS review, sandboxing) before enabling impersonation for high-risk networks.
   - Maintain replayable traces per platform for deterministic integration tests.

## Network Families and Candidate Projects
The following roadmap groups networks by similarity and suggests base implementations we can fork or study. Each entry lists the primary target, recommended reference project, integration stance, and required RE focus.

### Matrix-Native Bridge Ecosystem (Discord, Slack, Signal, Telegram, WhatsApp, Messenger, Instagram, Google Chat)
- **Reference Stack**: [`mautrix` bridges](https://github.com/mautrix) with per-service repositories (discord, slack, signal, telegram, whatsapp, facebook/meta, googlechat) already implementing puppeting workflows.
- **Plan**:
  1. Fork the relevant mautrix project and strip Matrix-specific homeserver bindings, retaining protocol and puppeting logic.
  2. Replace Matrix event emitters with StoneMQ publishers; map Matrix bridge state (double puppeting, portal rooms) to Msgr conversations.
  3. During RE Round A, record login/auth flows (e.g., Signal device registration, Meta Business tokens) to parameterise the Msgr credential vault schema.
  4. During RE Round B, exercise edge cases (media uploads, presence, typing notifications) to ensure the daemon contract covers them.
- **Special Cases**:
  - **Telegram**: Combine GramJS session management from mautrix-telegram with our existing queue envelope definitions for `link_account`, `outbound_message`, and `ack_update`.
  - **WhatsApp/Messenger/Instagram**: Pay attention to multi-device session persistence; reuse mautrix-meta's device sync logic while isolating WebSocket traffic in sandboxed containers.

### Matrix AppService Heritage (IRC, XMPP, Mattermost)
- **Reference Stack**: [`matrix-org` appservice bridges](https://github.com/matrix-org) for IRC and Slack, plus [`matrix-bifrost`](https://github.com/matrix-org/matrix-bifrost) and [`matrix-appservice-mattermost`](https://github.com/mattermost/matrix-as-mm)).
- **Plan**:
  1. Extract protocol adapters (irc-framework, xmpp.js/go-xmpp) and bind them to StoneMQ consumers.
  2. Retain the proven virtual user mapping tables as the source for Msgr's puppeting registry.
  3. RE Round A emphasises connection lifecycle (SASL, STARTTLS, XMPP resource binding). Round B validates history backfill (IRC log tail, XMPP MAM) against our `ack_offset` / `ack_receipt` envelopes.

### Discord-Specific Options
- **Reference Projects**: [`out-of-your-element`](https://gitdab.com/cadence/out-of-your-element) and [`matrix-appservice-discord`](https://github.com/matrix-org/matrix-appservice-discord).
- **Plan**:
  1. Start from `out-of-your-element` to leverage its puppeting fidelity and self-hosted gateway support.
  2. Use RE Round A to document Gateway intents, identify privileged scope requirements, and snapshot Member List syncing for channel metadata.
  3. During RE Round B, automate stage channel events, thread replies, and ephemeral message handling; add contract fixtures for interaction payloads (slash commands, buttons).

### Slack Ecosystem
- **Reference Projects**: [`mautrix/slack`](https://github.com/mautrix/slack), [`mx-puppet-slack`](https://gitlab.com/mx-puppet/slack/mx-puppet-slack).
- **Plan**:
  1. Combine mautrix's HTTP/RTM handling with mx-puppet's cookie-based login for workspaces lacking app installs.
  2. RE Round A captures Socket Mode and RTM WebSocket handshake plus Enterprise Grid routing.
  3. RE Round B confirms threading, message edits, and workflow events; map Slack file uploads to Msgr media service with signed URLs.

### Snapchat (Priority)
- **Reference Projects**: [`SnapWrap`](https://github.com/Rob--/SnapWrap) and [`snapchat` Python package](https://pypi.org/project/snapchat/).
- **Plan**:
  1. Allocate dedicated RE effort: instrument Android or web clients with Frida/mitmproxy to extract auth tokens and GraphQL endpoints.
  2. Implement a prototype daemon in Python using SnapWrap to manage login, session refresh, and story/message polling.
  3. RE Round A focuses on login, device fingerprinting, and retrieving message inbox streams.
  4. RE Round B expands to ephemeral message lifecycle, attachments, and friend management, ensuring we respect deletion semantics.
  5. Puppet modelling: store Bitmoji/avatar metadata and push ephemeral expiry timers into Msgr so clients honour disappearance rules.

### X (Twitter), iMessage, WeChat
- **Reference Projects**: [`mautrix/twitter`](https://github.com/mautrix/twitter), [`mautrix/imessage`](https://github.com/mautrix/imessage), [`matrix-wechat`](https://github.com/duo/matrix-wechat).
- **Plan**:
  1. Treat these as post-MVP due to higher legal/compliance risk.
  2. Use RE Round A to gather legal ToS considerations and document required on-device components (macOS bridge for iMessage, web automation for X/WeChat).
  3. During Round B prototype limited read-only ingestion before attempting impersonation.

### Snapchat Automation Safeguards
- Build sandbox containers with device emulation to reduce account bans.
- Rotate device identifiers and integrate captcha solvers only after legal review.
- Maintain RE notebooks capturing GraphQL schemas and session cookies for reproducibility.

## Execution Timeline (90-Day Horizon)
| Week | Milestone |
|------|-----------|
| 0    | Bridge SDK skeleton merged; StoneMQ contract frozen. |
| 1-2  | RE Round A completed for Telegram, Discord, Slack, Snapchat; publish findings to shared notebooks. |
| 3-4  | RE Round B completed with attachment + edge case coverage; update queue schemas and fixtures. |
| 5-6  | Prototype daemons for Telegram, Discord, Slack on StoneMQ; integrate Msgr inbound ingestion. |
| 7-8  | Snapchat daemon alpha with read-only inbox; establish ephemeral message handling hooks. |
| 9-10 | Outbound impersonation enabled for Telegram/Discord/Slack; compliance review kickoff. |
| 11-12| Snapchat outbound pilot; start research on iMessage/X/WeChat. |

## Deliverables
- RE notebooks per network, including handshake transcripts and rate limit tables.
- Updated queue contract specifications and schema fixtures reflecting discovered fields.
- Prototype daemon repositories aligned with the Msgr bridge SDK.
- Integration tests replaying captured traffic to validate daemon ↔ Msgr interoperability.
- Compliance checklist and risk assessment for high-ToS-risk platforms before production rollout.

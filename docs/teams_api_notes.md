# Microsoft Teams API Notes

## Primary Surface: Microsoft Graph

* Teams messaging is exposed through Microsoft Graph's `/chats`, `/teams`, and
  `/channels` resources. Sending messages uses the `chatMessage` resource under
  `/chats/{chat-id}/messages` or `/teams/{team-id}/channels/{channel-id}/messages`.
* Presence, roster management, and reactions are also handled through Graph.
  Change notifications (`/subscriptions`) provide webhook-style updates that we
  can translate into queue events for Msgr.
* Authentication relies on Azure AD OAuth 2.0 (authorization code flow). Tokens
  are scoped to the tenant and typically require the `Chat.ReadWrite` and
  `ChannelMessage.Send` permissions for user-level puppeting.

## Real-time Updates

* Persistent change notifications require an HTTPS webhook or websocket relay.
  For our bridge, we plan to consume Graph change notifications through a
  lightweight worker that renews subscriptions and pushes events onto StoneMQ.
* Microsoft is rolling out [Teams Live Share SDK](https://learn.microsoft.com/
  en-us/microsoftteams/platform/sbs-collab-overview) and [Event Hubs
  integrations](https://learn.microsoft.com/en-us/microsoftteams/platform/sbs-
  rsc-resource-specific-consent) but Microsoft Graph change notifications remain
  the most widely available option for chat messages.

## Limitations

* Tokens expire quickly (~1 hour). We need to store refresh tokens securely and
  refresh before expiry; the `TeamsBridgeDaemon` exposes hooks for that logic.
* Some tenants require resource-specific consent (RSC). The consent plan in the
  daemon's response includes guidance for performing the RSC step inside the
  embedded browser when necessary.
* Graph throttling is strict—batch roster updates and cache snapshots whenever
  possible.

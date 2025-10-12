# Snapchat Web Protocol Notes

These notes capture how the official Snapchat web client (v13.59.0 build 2218dc93)
bootstraps and talks to backend services based on the capture from
`captures/session-2025-10-12T18-27-09-925Z.jsonl` (1312 events, 608 filtered as
static asset noise).

## 1. Session bootstrap and authentication

1. **Entry redirects** – the browser is first redirected from
   `https://web.snapchat.com/` to `https://www.snapchat.com/web/` with `301/200`
   responses before any authenticated traffic happens.
2. **SSO hand-off** – unauthenticated sessions are bounced to
   `https://accounts.snapchat.com/accounts/sso` (`303` responses) with
   `client_id` parameters such as `web-calling-corp--prod` and `web-accounts`.
   The login page warns about Self-XSS repeatedly via console logging.
3. **Device attestation** – once signed in, the web app calls
   `POST https://session.snapchat.com/snap.security.WebAttestationService/BootstrapAttestationSession`
   with an `Authorization: Bearer …` header and binary `application/x-protobuf`
   payloads. The response issues the attestation tokens that later requests
   depend on.
4. **Web client token** – GraphQL-style requests to
   `https://web.snapchat.com/graphene/web` carry an
   `X-Snapchat-Web-Client-Auth: <hex>:<epoch>` header alongside the attested
   bearer token. The values rotate during the session (two distinct header
   values were observed) and are needed for chat APIs.
5. **Chat session refresh** – the client periodically hits
   `GET https://web.snapchat.com/web-chat-session/refresh?client_id=web-calling-corp--prod`
   right after obtaining new attestation tokens. Responses were empty bodies
   (`200`/`null`), suggesting the bridge must supply cookies/bearer tokens.

## 2. Messaging and sync workloads

1. **Outbound send** – chats are delivered via repeated
   `POST https://web.snapchat.com/web-blizzard/web/send` calls. Every request is
   `application/x-protobuf` with the same bearer token and an
   `X-Blizzard-Upload-Timestamp` aligned with the client clock. The capture shows
   dozens of attempts ending in `net::ERR_ABORTED`, likely because the session
   was torn down mid-flight. The bridge must pack the protobuf payloads (message
   text, media references, client context) and replay retries when transport
   drops.
2. **Delta sync** – timeline and conversation updates use gRPC-style endpoints
   such as `https://web.snapchat.com/com.snapchat.deltaforce.external.DeltaForce/DeltaSync`,
   `…/snapchat.atlas.gw.AtlasGw/SyncFriendData`,
   `…/snapchat.friending.server.FriendRequests/IncomingFriendSync` and
   `…/readreceipt-server/viewhistory`. All were invoked with the same bearer
   token and protobuf bodies.
3. **Story and Spotlight fetches** – content recommendations go through
   `POST https://web.snapchat.com/context/spotlight` (protobuf payloads
   containing a `web_stories_request` message with `enabled=true` flags and
   creator IDs) and `…/df-spotlight-prod/batch_stories` / `…/df-mixer-prod/soma/batch_stories`.
4. **Ads and targeting** – the client makes batched calls to
   `snapchat.cdp.cof.CircumstancesService/targetingQuery` via both `web.snapchat.com`
   and `aws.api.snapchat.com`, always with bearer tokens matching the chat
   session.

## 3. Telemetry and analytics

1. **First-party analytics** – `POST https://us-central1-gcp.api.snapchat.com/web-analytics/web/events`
   sends JSON payloads (captured after base64-encoding) that enumerate
   `event_name`, `experiment_id`, `study_name`, device viewport dimensions, and
   flags such as `"NATIVE_KEY_MANAGER_INIT"`, `"WEB_PERMISSION_UPDATE"`, and
   `"WEB_UPSELL"`.
2. **Error reporting** – the web app continually streams envelopes to
   `https://sentry.sc-prod.net/api/158/envelope/`.
3. **Version manifest** – every bootstrap fetches
   `https://www.snapchat.com/web/version.json?version=2218dc93&flavor=prod&variant=dweb_slash_web&type=BROWSER`.

## 4. Headers, tokens, and cookies

- No `Set-Cookie` headers were captured, implying the session reuses existing
  cookies established before recording started.
- `Authorization: Bearer <SCA …>` headers identify the authenticated user and are
  reused across analytics, chat, and discovery endpoints.
- `X-Snapchat-Web-Client-Auth` and `X-Blizzard-Upload-Timestamp` are mandatory for
  chat-specific routes.
- The client surfaces repeated console warnings (Norwegian and English) urging
  users not to paste code into the devtools console, matching Snapchat’s
  production hardening.

## 5. Implications for the msgr Snapchat bridge

- **Linking** requires orchestrating the SSO redirect flow, harvesting the
  `X-Snapchat-Web-Client-Auth` token, and completing the attestation bootstrap
  before the bridge can talk to chat APIs.
- **Session upkeep** must periodically refresh attestation and chat-session
  cookies using the `BootstrapAttestationSession` and `web-chat-session/refresh`
  endpoints when bearer tokens rotate.
- **Messaging** workers need protobuf serializers for `web-blizzard` send payloads
  and must capture retry-able client timestamps.
- **Sync** workers should drive `DeltaSync`, friend sync, read receipt history,
  and Spotlight/story batching to keep the Elixir core updated.
- **Telemetry hooks** can optionally forward Snapchat’s analytics events to
  msgr’s observability pipeline (they already include experiment IDs and device
  context that may help debugging bridge issues).

## 6. Recovering Snapchat’s protobuf message definitions

Most of the high-value endpoints in the capture exchange opaque
`application/x-protobuf` payloads. Because Snapchat has not published public
`.proto` schema files, the bridge must infer the wire format at runtime. The
web client bundles everything required to do so:

1. **Look for bundled descriptors** – the production web build ships protobuf
   descriptors as binary blobs that are fed to `protobufjs` during runtime.
   Search the `https://web.snapchat.com/` JavaScript bundles for base64 strings
   passed into `protobufjs.Root.fromDescriptor` / `fromJSON`, or for calls to
   helper functions such as `Object(_n.generate)` / `t.fromBinary`. These blobs
   decode into the full message schema. Dumping the bundle (e.g. using
   `node --experimental-fetch` and `esbuild --deobfuscate`) will surface those
   descriptors so they can be saved as canonical `.proto` files.
2. **Instrument the browser** – open DevTools on the web client and hook into
   the global `protobufjs` registry (e.g. `window.protobuf.Root`) after the app
   loads. The registry exposes the resolved message types and fields. Serialised
   `Type.toJSON()` output is enough to reconstruct `.proto` files for the bridge.
3. **Observe request payloads** – the capture already shows structure hints
   (strings that look like UUIDs, repeated message IDs, timestamps). Feeding the
   recorded binary payloads into `protobufjs.Root.lookupType("…")` after loading
   the descriptors lets us confirm field numbers/types.
4. **Handle schema churn** – keep the dumped descriptors in git and re-run the
   extraction whenever Snapchat ships a new `version.json` build ID. The bridge
   can pin the descriptor hash in the attestation bootstrap to detect drifts.

If an automated dump is not yet available, an interim workaround is to capture
the raw `ArrayBuffer` payloads from `fetch` and expose them to a dedicated
reverse engineering script; however, locating the `protobufjs` descriptor blob
is the fastest path to a complete schema map.

# Account management self-service plan

To support linking several identities to the same Messngr account we need a
self-service surface that lets end users review, add and remove credentials
without operator intervention. This page captures the first iteration of that
plan.

## Goals

- Give users visibility into every identity attached to their Messngr account
  (email, phone, external providers such as GitHub, Google Workspace, Facebook
  and future tenant-specific IDPs).
- Allow users to initiate new identity links from the client—kicking off OIDC
  authorization flows or SMS/email verification challenges—and confirm the
  outcome before the identity is activated.
- Provide controls for revoking compromised identities and terminating active
  sessions/devices associated with them.
- Surface audit history so both users and support teams can understand when
  identities were linked, verified or removed.

## First release scope

1. **Account overview screen** (web + Flutter) that lists:
   - Primary profile details (display name, handle, preferred locale/timezone).
   - Devices with last handshake time and ability to revoke.
   - Linked identities with provider badge, verification status and last used
     timestamp.
2. **Link identity wizard** that supports:
   - Email + phone verification (re-using existing OTP challenge endpoints).
   - External OIDC providers by redirecting to the IDP's `/authorize` URL and
     returning with a `state` token to confirm the link.
3. **Removal flow** with double confirmation, ensuring at least one verified
   identity remains before deletion.
4. **Activity log** stored as append-only audit entries so we can show "Linked
   GitHub (mikalv) 2 days ago" or "Revoked Facebook identity".

## Technical tasks

- Extend the `Messngr.Accounts` API with explicit link/unlink endpoints that
  enforce the business rules now baked into `ensure_identity/1`.
- Expose REST routes under `/api/account/identities` and `/api/account/devices`
  guarded by the IDP session so clients can manage their own account.
- Add a lightweight Phoenix LiveView admin screen for support staff to search
  accounts, inspect linked identities and trigger recovery flows.
- Instrument the IDP flows with structured logging + metrics (link attempts,
  verification latency, identity removal) to catch regressions early.

## Open questions

- Do we need policy rules per tenant (e.g. corporate tenants disallow personal
  providers)? Capture this in tenant metadata if yes.
- Should we expose SCIM hooks for enterprise tenants to automate identity
  lifecycle? Investigate once base flows are stable.
- How do we surface recovery options when all identities are revoked? Possible
  recovery codes or operator escalation channel.


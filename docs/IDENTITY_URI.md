# Msgr Identity URI Specification

## Overview

Every entity in Msgr (user, bot, bridged contact) is addressable via a URI. This enables federation, bridges to external networks, multi-device support, and deep linking from browsers and native apps.

## URI Format

```
msgr://user@domain/resource
```

| Component  | Description                          | Example                          |
|------------|--------------------------------------|----------------------------------|
| `msgr://`  | Scheme (registered for deep linking) | —                                |
| `user`     | Handle or identifier                 | `ola`, `4712345678`              |
| `domain`   | Routing domain                       | `msgr.no`, `slack-v1.eyr.msgr.no`|
| `/resource`| Device or client instance (optional) | `/macbook-pro`, `/iphone-12`     |

## Domain Hierarchy

Domains follow DNS hierarchy, read right to left:

```
bridge.team.msgr.no

msgr.no                      → platform root
eyr.msgr.no                  → team "Eyr"
slack-v1.eyr.msgr.no         → Slack bridge v1 for team Eyr
matrix-v1.eyr.msgr.no        → Matrix bridge v1 for team Eyr
irc-v1.eyr.msgr.no           → IRC bridge v1 for team Eyr
```

### Bridge versioning

Bridge protocol versions are encoded in the subdomain prefix:

```
slack-v1.eyr.msgr.no    → bridge version 1
slack-v2.eyr.msgr.no    → bridge version 2 (coexists during migration)
```

When a bridge is upgraded, old URIs remain valid via canonical URI resolution (see Contact Identity section below).

## Examples

### Native users

```
msgr://ola@msgr.no                    — native user, no device specified
msgr://ola@msgr.no/macbook-pro        — specific device
msgr://ola@msgr.no/iphone-12          — another device
msgr://4712345678@msgr.no/pixel-9     — user who kept phone number as handle
```

### Team context

```
msgr://ola@eyr.msgr.no               — Ola's identity within team Eyr
msgr://kari@acme.msgr.no             — Kari's identity within team Acme
```

### Bridged users

```
msgr://mikalv@slack-v1.eyr.msgr.no          — Slack user in Eyr workspace
msgr://per@matrix-v1.eyr.msgr.no            — Matrix user bridged to Eyr
msgr://peransen@irc-v1.eyr.msgr.no          — IRC user on Freenode via Eyr
msgr://bot-ci@teams-v1.acme.msgr.no/service — Teams bot bridged to Acme
```

### Bots and headless clients

```
msgr://deploybot@msgr.no/service      — native bot
msgr://rss-feed@eyr.msgr.no/service   — team-scoped bot
```

## Web URLs

Every URI has a corresponding web URL for browser access and sharing:

| Purpose              | Format                                    | Example                                |
|----------------------|-------------------------------------------|----------------------------------------|
| Profile (vanity)     | `https://æ.me/@user`                      | `https://æ.me/@mikalv`                |
| Profile (short)      | `https://msgr.no/@user`                   | `https://msgr.no/@mikalv`             |
| Profile (team)       | `https://team.msgr.no/@user`              | `https://eyr.msgr.no/@mikalv`         |
| Profile (bridged)    | `https://bridge.team.msgr.no/@user`       | `https://slack-v1.eyr.msgr.no/@mikalv`|
| DM action            | `https://æ.me/@user?action=dm`            | `https://æ.me/@mikalv?action=dm`      |
| Channel invite       | `https://team.msgr.no/#channel`           | `https://eyr.msgr.no/#general`        |
| Team invite          | `https://team.msgr.no/invite/CODE`        | `https://eyr.msgr.no/invite/abc123`   |

### Vanity short URL: æ.me

`æ.me` (Norwegian/Trøndersk for "me") serves as the vanity short URL for user profiles:

```
https://æ.me/@mikalv          — shortest shareable profile link
https://æ.me/@mikalv?action=dm — deep link to start DM
```

`æ.me/@user` redirects to `msgr.no/@user` or attempts `msgr://` deep link if app is installed. Ideal for business cards, social media bios, and sharing.

The IDN (Internationalized Domain Name) is `xn--4ca.me` in punycode.

### Browser behavior

When visiting a web URL (including æ.me):

1. **App installed + logged in** → attempt `msgr://` deep link to open in app
2. **Logged in (browser)** → show profile with actions (Send DM, Invite, etc.)
3. **Not logged in** → show public profile card with Open Graph meta tags + "Open in Msgr" / "Download Msgr"

## Handle Assignment

At registration:

1. User chooses a handle → `msgr://ola@msgr.no`
2. No choice + phone number → `msgr://4712345678@msgr.no`
3. No choice + email `kari@firma.no` → `msgr://kari@msgr.no`
   - If taken → `msgr://kari-a7x@msgr.no` (random suffix)

Handle can be changed **once** after initial registration. After that it is permanent.

In team context, the profile display name can differ from the handle, controlled by the team owner's settings.

## Contact Identity Model

A contact represents a **person**, not a URI. One person may have multiple URIs across networks.

```
Contact: "Per Hansen"
  ├── msgr://per@msgr.no                     (native, primary)
  ├── msgr://per@matrix-v1.eyr.msgr.no       (Matrix bridge)
  └── msgr://peransen@irc-v1.eyr.msgr.no     (IRC bridge)
```

### Linking identities

- **Manual**: User drags a DM conversation onto an existing contact to merge
- **Automatic**: When a bridged user verifies on Msgr natively, system suggests merge

### Canonical URI

When a bridge is upgraded (v1 → v2), old URIs resolve to the new canonical:

```
msgr://per@slack-v1.eyr.msgr.no  →  canonical: msgr://per@slack-v2.eyr.msgr.no
```

Old URIs continue to work. Clients follow canonical for display and routing.

## Database Schema

### Public schema (global)

```sql
-- URI stored as first-class field on accounts
accounts.uri         TEXT UNIQUE   -- "msgr://ola@msgr.no"
accounts.handle      TEXT UNIQUE   -- "ola"

-- Full URI with device/resource
account_devices.resource   TEXT    -- "macbook-pro"
account_devices.full_uri   TEXT UNIQUE  -- "msgr://ola@msgr.no/macbook-pro"

-- Contact identity linking
contacts.id               UUID PK
contacts.owner_account_id FK → accounts
contacts.display_name     TEXT

contact_identities.id           UUID PK
contact_identities.contact_id   FK → contacts
contact_identities.uri          TEXT UNIQUE
contact_identities.canonical_uri TEXT
contact_identities.bridge_type  TEXT    -- "native", "slack", "matrix", "irc"
contact_identities.bridge_meta  JSONB
contact_identities.is_primary   BOOLEAN DEFAULT false
contact_identities.verified_at  TIMESTAMP
```

### Tenant schema (per team)

```sql
-- Team-scoped profile, separate from global identity
profiles.account_id  FK → public.accounts
-- Team URI derived: msgr://handle@team-slug.msgr.no
```

## Environments

URIs and domains are environment-aware:

| Environment | Domain           | Wildcard           | Purpose                |
|-------------|------------------|--------------------|------------------------|
| Development | `dev.msgr.no`    | `*.dev.msgr.no`    | Local/staging dev work |
| Production  | `msgr.no`        | `*.msgr.no`        | Live users             |

### Examples per environment

```
Development:
  msgr://ola@dev.msgr.no                     — dev native user
  msgr://ola@eyr.dev.msgr.no                 — dev team Eyr
  msgr://mikalv@slack-v1.eyr.dev.msgr.no     — dev Slack bridge
  https://dev.msgr.no/@ola                   — dev web profile
  https://eyr.dev.msgr.no/#general           — dev channel link

Production:
  msgr://ola@msgr.no                         — prod native user
  msgr://ola@eyr.msgr.no                     — prod team Eyr
  msgr://mikalv@slack-v1.eyr.msgr.no         — prod Slack bridge
  https://msgr.no/@ola                       — prod web profile
  https://eyr.msgr.no/#general               — prod channel link
```

The environment is derived from the domain root (`dev.msgr.no` vs `msgr.no`). Client configuration determines which root domain to use. URIs from one environment should never resolve in another.

## DNS and Routing

All team and bridge subdomains use wildcard DNS:

```
*.msgr.no      →  A record → production load balancer
*.dev.msgr.no  →  A record → development server
```

The edge router (Elixir/Rust gateway) inspects the `Host` header to determine:
- Which environment (dev vs prod)
- Which team (tenant schema) to route to
- Which bridge service to forward to (if bridge subdomain)

## Future Considerations

- **Personal mode** (Telegram-like): Uses `msgr://user@msgr.no` directly, no team context
- **Inter-team channels**: Shared channels link via public schema, messages synced via events
- **Federation**: Other Msgr instances could run on their own domains (`msgr://user@company.com`)
- **E2EE key per device**: The `/resource` component maps to device-specific encryption keys

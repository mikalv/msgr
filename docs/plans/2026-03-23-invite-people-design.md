# Design: Invite People to Team (#117)

## Overview

Link-based team invitations. Any team member can generate an invite link that expires after 7 days. Recipients click the link, log in (or register), and auto-join the team.

## Data Model

New `invite_links` table in **public schema** (must resolve team before knowing tenant):

```sql
CREATE TABLE invite_links (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id       UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  code          VARCHAR(8) NOT NULL UNIQUE,
  created_by_account_id UUID NOT NULL REFERENCES accounts(id),
  expires_at    TIMESTAMPTZ NOT NULL,
  used_count    INTEGER NOT NULL DEFAULT 0,
  revoked       BOOLEAN NOT NULL DEFAULT false,
  inserted_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX invite_links_code_idx ON invite_links(code);
CREATE INDEX invite_links_team_id_idx ON invite_links(team_id);
```

Code is 8-char nanoid — short for sharing, unique enough to avoid collisions.

## API Endpoints

### Authenticated (require team membership)

```
POST   /api/teams/:slug/invites     — Generate new invite link
GET    /api/teams/:slug/invites     — List active links
DELETE /api/teams/:slug/invites/:id — Revoke a link
```

**POST response:**
```json
{
  "id": "uuid",
  "code": "xK9f2mQp",
  "url": "https://dev.msgr.no/invite/xK9f2mQp",
  "expires_at": "2026-03-30T22:00:00Z"
}
```

### Public (require auth but not team membership)

```
POST   /api/invite/:code            — Redeem invite code
```

Validates code (not expired, not revoked), calls `TeamManagement.join_team()`, increments `used_count`, returns team info for navigation.

## Flutter Frontend

### Generate Link (sidebar)

"Invite people" button in sidebar header → calls create endpoint → shows dialog with link + copy button.

### Redeem Link (web)

1. URL is `/invite/:code` → show "Joining..." spinner
2. Logged in? → call `POST /api/invite/:code` → navigate to team
3. Not logged in? → show login → store `pending_invite_code` in SharedPreferences → after login, redeem → navigate

### Native apps

Web link opens in browser. Native URI scheme (`msgr://invite/:code`) deferred to issue #124.

## Authorization

- Any team member can create invite links
- Any authenticated user can redeem a valid link
- Only link creator or team owner/admin can revoke

## Out of Scope

- Max uses per link
- Email/SMS sending
- Admin UI for managing links
- Native URI scheme (#124)
- Role selection (all invitees become "member")

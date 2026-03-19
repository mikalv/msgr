# MVP Slack Pilot — Implementation Plan

**Goal**: Internal pilot for 5-10 users as Slack replacement
**Platforms**: Desktop + Mobile + Web (Flutter)
**Quality bar**: Slack/Discord level — messages never lost, drafts persist, delivery states visible

## Architecture

```
Flutter Client (desktop + mobil + web)
    │  NOISE WebSocket (encrypted transport)
    ▼
Rust Gateway (:8443)
    │  gRPC / plaintext
    ▼
Elixir/Phoenix Backend (:4000)
    │
    ├── PostgreSQL (public + tenant schemas)
    ├── Prism (:3080) — message search
    ├── MinIO — files and media
    └── Redis — cache, presence, typing
```

## Data Model

See `docs/IDENTITY_URI.md` for full URI specification.

### Public schema (global)

```sql
accounts (
  id UUID PK,
  handle TEXT UNIQUE,
  uri TEXT UNIQUE,              -- "msgr://ola@msgr.no"
  email TEXT,
  phone TEXT,
  handle_changed_at TIMESTAMP,
  inserted_at, updated_at
)

account_devices (
  id UUID PK,
  account_id FK → accounts,
  resource TEXT,                -- "iphone-12"
  full_uri TEXT UNIQUE,         -- "msgr://ola@msgr.no/iphone-12"
  push_token JSONB,
  noise_public_key BYTEA,
  last_seen_at TIMESTAMP
)

teams (
  id UUID PK,
  name TEXT,
  slug TEXT UNIQUE,             -- "eyr"
  schema_name TEXT UNIQUE,      -- "tenant_<uuid>"
  domain TEXT UNIQUE,           -- "eyr.msgr.no"
  owner_account_id FK → accounts,
  settings JSONB
)

team_memberships (
  account_id FK → accounts,
  team_id FK → teams,
  role TEXT,                    -- "owner", "admin", "member"
  joined_at TIMESTAMP
)

contacts (
  id UUID PK,
  owner_account_id FK → accounts,
  display_name TEXT,
  notes TEXT,
  inserted_at TIMESTAMP
)

contact_identities (
  id UUID PK,
  contact_id FK → contacts,
  uri TEXT UNIQUE,
  canonical_uri TEXT,
  bridge_type TEXT,
  bridge_meta JSONB,
  is_primary BOOLEAN DEFAULT false,
  verified_at TIMESTAMP
)
```

### Tenant schema (per team: tenant_<uuid>)

```sql
profiles (
  id UUID PK,
  account_id FK → public.accounts,
  display_name TEXT,
  avatar_url TEXT,
  email TEXT,
  phone TEXT,
  role TEXT
)

channels (
  id UUID PK,
  name TEXT,
  slug TEXT,                    -- "general", "dev"
  kind TEXT,                    -- "channel", "dm", "group_dm"
  visibility TEXT,              -- "public", "private"
  topic TEXT,
  created_by FK → profiles,
  inserted_at TIMESTAMP
)

channel_memberships (
  channel_id FK → channels,
  profile_id FK → profiles,
  role TEXT,                    -- "admin", "member"
  joined_at TIMESTAMP,
  PRIMARY KEY (channel_id, profile_id)
)

messages (
  id UUID PK,
  channel_id FK → channels,
  sender_profile_id FK → profiles,
  thread_parent_id FK → messages,
  content JSONB,
  media_refs TEXT[],
  edited_at TIMESTAMP,
  inserted_at TIMESTAMP
)

reactions (
  message_id FK → messages,
  profile_id FK → profiles,
  emoji TEXT,
  PRIMARY KEY (message_id, profile_id, emoji)
)

media_uploads (
  id UUID PK,
  profile_id FK → profiles,
  object_key TEXT,
  content_type TEXT,
  filename TEXT,
  size BIGINT,
  checksum TEXT,
  inserted_at TIMESTAMP
)

read_cursors (
  channel_id FK → channels,
  profile_id FK → profiles,
  last_read_message_id FK → messages,
  PRIMARY KEY (channel_id, profile_id)
)
```

---

## Implementation Teams

### Team 1: Backend & Database (Elixir)

**Scope**: Tenant schemas, API endpoints, Phoenix channels, Prism integration

#### Phase 1.1 — Tenant Schema Foundation
- [ ] Add `Msgr.Tenancy` module: create/drop tenant schemas, run migrations per tenant
- [ ] Evaluate Triplex library vs custom implementation
- [ ] Write tenant-scoped migrations for: profiles, channels, channel_memberships, messages, reactions, media_uploads, read_cursors
- [ ] Update public schema: add `teams`, `team_memberships`, `contacts`, `contact_identities` tables
- [ ] Add `uri` and `handle` columns to `accounts`
- [ ] Add `account_devices` table with `resource` and `full_uri`
- [ ] Implement `Repo.put_prefix("tenant_#{schema_name}")` helper
- [ ] Write seed script: create a test team with tenant schema

#### Phase 1.2 — Room → Channel Cleanup
- [ ] Audit all Elixir modules using "room" terminology — rename to "channel"
- [ ] Rename contexts: `Msgr.Rooms` → `Msgr.Channels`
- [ ] Rename schemas: `Msgr.Rooms.Room` → `Msgr.Channels.Channel`
- [ ] Update all Phoenix channel topics from `room:*` to `channel:*`
- [ ] Update router endpoints
- [ ] Ensure backward compatibility during transition (alias old names if needed temporarily)

#### Phase 1.3 — Core API Endpoints
- [ ] `POST /api/teams` — create team (creates tenant schema)
- [ ] `POST /api/teams/:slug/join` — join team (creates profile in tenant)
- [ ] `GET /api/teams/:slug/channels` — list channels in team
- [ ] `POST /api/teams/:slug/channels` — create channel
- [ ] `GET /api/teams/:slug/channels/:id/messages` — paginated messages
- [ ] `POST /api/teams/:slug/channels/:id/messages` — send message
- [ ] `POST /api/teams/:slug/channels/:id/messages/:id/reactions` — add reaction
- [ ] `DELETE /api/teams/:slug/channels/:id/messages/:id/reactions/:emoji` — remove reaction
- [ ] `GET /api/teams/:slug/channels/:id/threads/:id` — get thread
- [ ] `POST /api/teams/:slug/channels/:id/messages/:id/thread` — reply in thread
- [ ] `PUT /api/teams/:slug/channels/:id/read_cursor` — mark as read
- [ ] `GET /api/teams/:slug/profiles` — list team members
- [ ] `PUT /api/teams/:slug/profiles/me` — update my team profile
- [ ] Media upload: `POST /api/teams/:slug/media/presign` — get presigned upload URL
- [ ] DM creation: `POST /api/teams/:slug/dms` — create DM channel between profiles

#### Phase 1.4 — Phoenix Channels (Realtime)
- [ ] `team:{slug}` channel — team-wide events (member join/leave, channel created)
- [ ] `channel:{id}` channel — message events, typing, reactions, read cursors
- [ ] `presence:{slug}` channel — online/offline status per team
- [ ] Typing indicators: broadcast typing start/stop per channel
- [ ] Unread counts: push unread count updates when new messages arrive
- [ ] Thread notifications: push event when thread you're in gets a reply

#### Phase 1.5 — Prism Integration
- [ ] Add Prism to docker-compose (port 3080)
- [ ] Create collection schema for messages (text content, channel_id, team, sender, timestamp)
- [ ] Async indexing: GenServer that listens for new messages and indexes to Prism
- [ ] `GET /api/teams/:slug/search?q=` — search endpoint that queries Prism
- [ ] Handle tenant isolation in search (filter by team schema)

#### Phase 1.6 — Docker & Infrastructure
- [ ] Update docker-compose.yml with all services
- [ ] Add Prism service
- [ ] Ensure database migrations run on startup (public + all tenant schemas)
- [ ] Health check endpoints for all services
- [ ] Environment-based config: `*.dev.msgr.no` vs `*.msgr.no`
- [ ] Wildcard DNS documentation

---

### Team 2: Flutter Client — Layout & Navigation

**Scope**: New app shell, team switching, channel list, responsive layout

#### Phase 2.1 — App Shell (Slack/Discord Hybrid)
- [ ] New `AppShell` widget: 3-column responsive layout
  - Column 1 (56px): Team icon rail (Discord-style)
  - Column 2 (240px): Channel list + DMs + search for selected team
  - Column 3 (flex): Chat area
- [ ] Mobile: stack navigation (team → channel list → chat)
- [ ] Tablet: 2-column (channel list + chat)
- [ ] Desktop: full 3-column
- [ ] Team icon rail: avatar/initials per team, `+` button for join/create
- [ ] Active team highlight, unread badge per team
- [ ] Collapse/expand channel list sidebar

#### Phase 2.2 — Channel List
- [ ] Channel sections: "Channels" header with collapse, "Direct Messages" header
- [ ] Channel item: `#name`, unread count badge, bold when unread
- [ ] DM item: avatar, name, presence dot, unread count
- [ ] "Create channel" button
- [ ] "New DM" button with user search
- [ ] Sort: unread first, then by activity

#### Phase 2.3 — Team Switching & Riverpod Migration
- [ ] `teamProvider` → full Riverpod StateNotifier with tenant context
- [ ] `channelListProvider` — channels for current team
- [ ] `currentChannelProvider` — selected channel
- [ ] `messagesProvider(channelId)` — paginated messages with realtime updates
- [ ] `threadProvider(messageId)` — thread messages
- [ ] `presenceProvider` — online status map
- [ ] `unreadProvider` — unread counts per channel
- [ ] `typingProvider(channelId)` — who's typing
- [ ] Break up ChatViewModel (1093 lines) into these smaller providers
- [ ] Team switch: disconnect from old team channels, connect to new

#### Phase 2.4 — Desktop Polish
- [ ] macOS: native menu bar (File, Edit, View, Window, Help)
- [ ] macOS: Cmd+K for quick channel switcher
- [ ] macOS: Cmd+N for new message
- [ ] macOS: Cmd+[ / Cmd+] for navigation history
- [ ] Windows/Linux: equivalent keyboard shortcuts
- [ ] System tray with unread badge
- [ ] Desktop notifications (native)
- [ ] Proper window lifecycle (restore position/size)

---

### Team 3: Flutter Client — Chat Experience

**Scope**: Message display, threads, reactions, file sharing, drafts, delivery states

#### Phase 3.1 — Message Display
- [ ] Message bubble: avatar, sender name, timestamp, content
- [ ] Markdown rendering in messages
- [ ] Link previews (existing flutter_link_previewer)
- [ ] Image inline preview (thumbnails, click to expand)
- [ ] File attachment display (icon, filename, size, download button)
- [ ] Edit indicator ("edited" label)
- [ ] Message grouping: consecutive messages from same sender collapse avatar

#### Phase 3.2 — Threads
- [ ] Thread indicator on messages: "N replies" with participant avatars
- [ ] Click thread indicator → open thread panel (right side on desktop, full screen on mobile)
- [ ] Thread panel: shows parent message + thread replies
- [ ] Thread composer (reuse existing composer)
- [ ] "Also send to channel" checkbox in thread composer
- [ ] Thread notification badge in channel list

#### Phase 3.3 — Reactions
- [ ] Reaction bar below messages (compact emoji pills with count)
- [ ] Click reaction → toggle my reaction
- [ ] `+` button → emoji picker to add new reaction
- [ ] Hover reaction → tooltip showing who reacted
- [ ] Quick reactions: common emoji shortcuts

#### Phase 3.4 — File Sharing
- [ ] Drag-and-drop files onto chat area
- [ ] Paste images from clipboard
- [ ] Upload progress indicator
- [ ] Attachment preview before sending (in composer)
- [ ] Image gallery view (swipe through images in channel)
- [ ] File download with progress

#### Phase 3.5 — Draft Persistence & Delivery States
- [ ] Auto-save draft per channel to local DB (libmsgr)
- [ ] Restore draft when switching back to channel
- [ ] Drafts survive app restart
- [ ] Channel list shows "draft" indicator
- [ ] Message delivery states in UI:
  - ⏳ Sending (optimistic, shown immediately)
  - ✓ Sent (server acknowledged)
  - ✓✓ Delivered (recipient received)
  - Failed (greyed out, retry button)
- [ ] Failed messages: tap to retry, long-press for options (retry, edit, delete)
- [ ] Offline banner: "You're offline — messages will send when reconnected"
- [ ] Outgoing queue status: "N messages waiting to send"

#### Phase 3.6 — Search UI
- [ ] Cmd+K / Ctrl+K: Quick switcher (channels + DMs + recent)
- [ ] Search bar in channel list → full search (Prism-backed)
- [ ] Search results: message preview with channel name, timestamp, highlight
- [ ] Click result → navigate to message in channel (scroll to + highlight)
- [ ] Filter: by channel, by person, date range

---

### Team 4: Rust Gateway & Infrastructure

**Scope**: Gateway updates for tenant routing, Docker hardening, monitoring

#### Phase 4.1 — Gateway Tenant Routing
- [ ] Parse `Host` header to determine team (subdomain → team slug)
- [ ] Pass team context to Phoenix backend in proxied requests
- [ ] WebSocket: include team slug in connection metadata
- [ ] Validate team membership before proxying

#### Phase 4.2 — Docker Production Setup
- [ ] Multi-stage Dockerfile for Elixir backend (builder + runner)
- [ ] Multi-stage Dockerfile for Rust gateway
- [ ] Prism service in docker-compose
- [ ] Redis service in docker-compose
- [ ] MinIO service in docker-compose
- [ ] PostgreSQL with initialization script (create public schema tables)
- [ ] Health checks on all services
- [ ] Volume mounts for persistent data
- [ ] `.env.example` with all required variables
- [ ] `docker-compose.dev.yml` override for development
- [ ] Single `docker compose up` starts everything

#### Phase 4.3 — Monitoring
- [ ] Prometheus metrics for: message throughput, WebSocket connections, NOISE handshakes
- [ ] Grafana dashboard: messages/sec, active users, error rate
- [ ] Structured logging (JSON) to stdout for all services
- [ ] Error alerting setup (basic, for pilot)

---

## Execution Order & Dependencies

```
Week 1:
  Team 1: Phase 1.1 (tenant schemas) + 1.2 (room→channel cleanup)
  Team 2: Phase 2.1 (app shell) + 2.2 (channel list)
  Team 3: Phase 3.1 (message display)
  Team 4: Phase 4.2 (Docker setup)

Week 2:
  Team 1: Phase 1.3 (API endpoints)        ← depends on 1.1, 1.2
  Team 2: Phase 2.3 (Riverpod migration)   ← depends on 2.1
  Team 3: Phase 3.2 (threads) + 3.3 (reactions)
  Team 4: Phase 4.1 (gateway routing)

Week 3:
  Team 1: Phase 1.4 (Phoenix channels)     ← depends on 1.3
  Team 2: Phase 2.4 (desktop polish)
  Team 3: Phase 3.4 (file sharing) + 3.5 (drafts/delivery)
  Team 4: Phase 4.3 (monitoring)

Week 4:
  Team 1: Phase 1.5 (Prism integration)
  Team 2+3: Integration testing, bug fixes
  Team 3: Phase 3.6 (search UI)            ← depends on 1.5
  All: End-to-end testing with docker compose up

Week 5:
  All: Polish, bug fixes, pilot onboarding
```

## Non-Goals (Deferred)

- E2EE (Double Ratchet / MLS) — see GitHub issue #66
- Personal mode (Telegram-like)
- Bridge integrations (Slack, Teams, Matrix, IRC)
- Inter-team channels
- Voice/video calls
- Admin panel / team settings UI
- App store deployment
- Federation

## Key Design Decisions

1. **Tenant schemas per team** — data isolation, GDPR compliance, independent scaling
2. **URI-based identity** (`msgr://user@domain/resource`) — see docs/IDENTITY_URI.md
3. **Channels not rooms** — consistent terminology throughout
4. **Threads as first-class** — `thread_parent_id` on messages, no separate table
5. **Prism for search** — own Rust search engine, ES-compatible API
6. **NOISE transport** — encrypted tunnel to gateway, E2EE deferred
7. **Refactor not rewrite** — keep composer, chat kit, services; rebuild shell and providers
8. **Docker-first** — all services in docker-compose for dev server
9. **Message reliability** — drafts persist, delivery states visible, retry on failure

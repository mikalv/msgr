# Relay App Marketplace — Design Specification

## Overview

An in-app marketplace where teams can discover, install, and manage third-party apps and integrations. Combines a curated central directory with support for custom/private apps via manifest URL.

## Permissions Model

- **Browse:** All team members can browse and suggest apps
- **Install/configure:** Only team owner and admins
- **Channel config:** Admins of the channel or team

## Data Model

### App (extends existing `Messngr.Apps.App`)

New fields:
- `category` — enum: productivity, developer-tools, communication, calendar, custom
- `featured` — boolean, curated by us
- `install_count` — integer, incremented on install
- `config_schema` — JSONB, defines secrets/config fields for install
- `channel_config_schema` — JSONB, defines per-channel settings
- `required_scopes` — array of strings: messages:read, messages:write, channels:read, members:read

### Channel metadata (new column)

`metadata` JSONB column on tenant `channels` table:
```json
{
  "apps": {
    "github": {"repo": "mikalv/relay", "notify_prs": true},
    "calendar": {"calendar_id": "team@relay.dm"}
  }
}
```

Each app reads/writes only under `apps.<app_slug>`. Schema enforced by `channel_config_schema`.

### AppInstallation (extends existing)

`config` field stores:
```json
{
  "channels": ["channel-id-1", "channel-id-2"],
  "secrets": {"github_token": "encrypted:..."},
  "settings": {"repo": "mikalv/relay"}
}
```

## API Endpoints

### Directory (public, authenticated)
- `GET /api/apps/directory?q=search&category=developer-tools` — browse apps
- `GET /api/apps/:slug` — app detail

### Team-scoped (admin only for mutations)
- `GET /api/teams/:slug/apps` — installed apps (exists)
- `POST /api/teams/:slug/apps/:app_slug/install` — install with config + channel bindings
- `PATCH /api/teams/:slug/apps/:app_slug` — update config/bindings
- `DELETE /api/teams/:slug/apps/:app_slug` — uninstall (exists)
- `GET /api/teams/:slug/apps/:app_slug/logs` — webhook delivery log

### Bot tokens (exists from #96)
- `GET /api/teams/:slug/apps/:app_slug/tokens` — list
- `POST /api/teams/:slug/apps/:app_slug/tokens` — create
- `DELETE /api/teams/:slug/apps/:app_slug/tokens/:id` — revoke

### Channel app config
- `GET /api/teams/:slug/channels/:id/apps/:app_slug/config` — read
- `PUT /api/teams/:slug/channels/:id/apps/:app_slug/config` — update (admin)

## Installation Flow

1. **Scope review** — admin sees what the app needs access to
2. **Config input** — auto-generated form from config_schema (string, secret, select, boolean, url)
3. **Channel binding** — multi-select which channels the app operates in
4. **Confirmation** — summary of scopes + channels + config
5. **Post-install** — system message in bound channels, webhook dispatch starts

Custom apps: admin pastes manifest URL, Relay fetches it, same flow.

## Flutter UI

### Team Settings > Apps tab

Three views:

**Browse:**
- Search bar
- Featured apps (horizontal scroll cards)
- Category filter chips
- App cards: icon, name, description, install count, Install button
- "Your Apps" section for private/custom apps

**App detail dialog:**
- Icon + name + developer
- Description
- Scope review with icons
- Config form (auto-generated from schema)
- Channel binding multi-select
- Install button

**Installed:**
- List of installed apps with active/paused status
- Per app: edit config, change bindings, view logs, uninstall
- Bot tokens section

### Channel Settings > Apps tab (new)

Per-channel app configuration. Auto-generated form from `channel_config_schema`. Each installed app that has channel config shows its settings here.

## Config Schema Format

```json
{
  "github_token": {
    "type": "secret",
    "label": "GitHub Personal Access Token",
    "required": true
  },
  "repo": {
    "type": "string",
    "label": "Repository (owner/name)",
    "placeholder": "mikalv/relay",
    "required": true
  },
  "notify_prs": {
    "type": "boolean",
    "label": "Notify on pull requests",
    "default": true
  },
  "environment": {
    "type": "select",
    "label": "Environment",
    "options": ["production", "staging", "development"],
    "default": "production"
  }
}
```

## App Distribution

- **Central directory:** Curated apps hosted at relay.dm, reviewed and approved
- **Custom apps:** Anyone can add via manifest URL, appears as "private" to the team
- **Developer portal:** Future — apps.relay.dm for publishing and managing apps (see #182)

## Webhook Dispatch (built in #97)

Installed apps with webhook_url receive events:
- HMAC-SHA256 signed payloads
- Headers: X-Relay-Event, X-Relay-Signature, X-Relay-Delivery
- Exponential backoff retry (5 attempts)
- Only events from bound channels are dispatched

## First-party Apps (planned)

- **GitHub** — PR/issue notifications, /issue command
- **Calendar** — JMAP calendar integration, event reminders
- **Jira** — issue tracking (future)
- **RSS** — feed reader bot

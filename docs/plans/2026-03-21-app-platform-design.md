# Msgr App Platform — Design Specification

## Overview

An extensible app/plugin system for Msgr, inspired by Slack's app platform but improved based on known pain points. Apps can provide slash commands, bot users, event subscriptions, and channel bindings.

## Executor Modes

### Mode B: Built-in (Elixir)

First-party apps running inside the BEAM. Zero latency, full DB access.

**Examples:** /poll, /remind, /status, /topic
**Use case:** Core features that ship with Msgr

```elixir
defmodule MsgrApps.Poll do
  @behaviour MsgrApp.Executor

  def execute(%{command: "poll", args: args, channel: channel, user: user}) do
    # Parse args, create poll, post to channel
    {:ok, %{message: "Poll created!", interactive: poll_widget}}
  end
end
```

### Mode C: Bot over WebSocket

Bots that connect as regular users via Phoenix Channels. Simplest developer experience — no server hosting needed for the bot developer, but they run their own process.

**Examples:** Kåre (LLM bot), CI/CD notifier, RSS feed bot
**Use case:** Custom bots, AI agents

```
Developer experience:
1. Team admin creates bot token in settings
2. Bot connects: MsgrClient(token: "bot-xxx").connect()
3. Bot joins channels, listens for events, sends messages
4. Bot is just another user with a "bot" badge
```

### Mode A: Webhook

External services that receive events via HTTP POST. No timeout requirement — async response via API callback.

**Examples:** GitHub integration, Jira, PagerDuty
**Use case:** Third-party SaaS integrations

```
Flow:
1. Event occurs in Msgr (message, command, etc.)
2. Msgr POSTs to app's webhook URL (signed with app secret)
3. App processes (can take minutes)
4. App calls Msgr API to post response
   POST /api/apps/{app_id}/channels/{channel_id}/messages
```

**Improvement over Slack:** No 3-second timeout. App acknowledges receipt (202), processes async, posts result when ready.

### Mode D: LLM Executor (No-code)

Define a prompt + tools in config. Msgr runs the LLM internally. No code required.

**Examples:** /issue, /summarize, /translate, /ask
**Use case:** AI-powered commands that team admins can create without coding

```yaml
# Team admin defines this in settings UI or YAML
commands:
  issue:
    description: "Opprett GitHub issue fra naturlig språk"
    executor: llm
    model: "qwen3.5-abliterated-35b"  # or team's default model
    system_prompt: |
      Du er en GitHub-assistent. Basert på brukerens beskrivelse,
      opprett en strukturert GitHub issue med tittel, beskrivelse,
      og foreslåtte labels.
    tools:
      - github.create_issue
      - github.list_labels
      - github.list_milestones
    required_secrets: [github_token]
    channel_binding: repo
    response_style: system_message  # post result as system message
```

### Mode E: Hosted Bot (Future)

Sandboxed bot execution hosted by Msgr. User uploads code, we run it in isolation.

**Security model:**
- Each bot runs in its own container (gVisor/Firecracker)
- Network: only allowed to call Msgr API + whitelisted external URLs
- Resource limits: CPU, memory, execution time per invocation
- No filesystem persistence (use Msgr KV store API)
- Code review / approval process for public apps
- Signed container images

**Runtime options:**
- Deno (TypeScript/JavaScript) — sandboxed by default
- WASM — strongest isolation
- Docker + gVisor — most flexible

**NOT for MVP.** This requires significant infrastructure. Start with modes B/C/D, add hosted execution later.

---

## Data Model

### Public Schema

```sql
-- App definitions (global registry)
apps (
  id UUID PK,
  slug TEXT UNIQUE,               -- "github", "jira", "llm-assistant"
  name TEXT NOT NULL,
  description TEXT,
  icon_url TEXT,
  developer_id UUID FK → accounts,  -- who created the app
  developer_name TEXT,
  manifest JSONB NOT NULL,        -- full app manifest
  visibility TEXT DEFAULT 'private',  -- 'public' (marketplace), 'private', 'team-only'
  executor_type TEXT NOT NULL,    -- 'builtin', 'webhook', 'bot', 'llm'
  webhook_url TEXT,               -- for webhook executor
  webhook_secret TEXT,            -- HMAC signing secret
  bot_account_id UUID FK → accounts,  -- for bot executor
  status TEXT DEFAULT 'active',   -- 'active', 'suspended', 'deprecated'
  inserted_at, updated_at
)

-- App installations per team
app_installations (
  id UUID PK,
  app_id UUID FK → apps,
  team_id UUID FK → teams,
  installed_by UUID FK → accounts,
  config JSONB DEFAULT '{}',      -- team-specific config (repo URLs, etc.)
  secrets_encrypted BYTEA,        -- encrypted secrets (API keys, tokens)
  enabled_scopes TEXT[],          -- what the app can do in this team
  enabled_channels UUID[],       -- null = all channels, or specific channel IDs
  status TEXT DEFAULT 'active',
  installed_at TIMESTAMP,
  updated_at TIMESTAMP,
  UNIQUE(app_id, team_id)
)

-- Slash command registry (derived from app manifests, cached for fast lookup)
slash_commands (
  id UUID PK,
  app_id UUID FK → apps,
  name TEXT NOT NULL,             -- "issue", "poll", "remind"
  description TEXT,
  args_schema JSONB,              -- { "text": "required", "repo": "optional" }
  permissions TEXT DEFAULT 'member',  -- 'owner', 'admin', 'member'
  UNIQUE(app_id, name)
)

-- Bot tokens (for Mode C bots)
bot_tokens (
  id UUID PK,
  app_installation_id UUID FK → app_installations,
  token_hash TEXT NOT NULL,       -- hashed token for lookup
  label TEXT,                     -- "production", "dev"
  scopes TEXT[],
  last_used_at TIMESTAMP,
  expires_at TIMESTAMP,
  revoked_at TIMESTAMP,
  inserted_at TIMESTAMP
)
```

### Tenant Schema (per team)

```sql
-- Bot profiles in tenant (one per installed app with bot capability)
-- Uses existing profiles table with:
--   account_id: NULL (bots don't have accounts)
--   role: 'bot'
--   app_id: reference to the app (new column on profiles)

-- Command execution log
command_executions (
  id UUID PK,
  app_id UUID,
  command_name TEXT,
  channel_id UUID FK → channels,
  triggered_by UUID FK → profiles,
  args JSONB,
  status TEXT,                    -- 'pending', 'running', 'completed', 'failed'
  result JSONB,
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  inserted_at TIMESTAMP
)

-- Channel-app bindings (e.g., #msgr → github repo mikalv/msgr)
channel_app_configs (
  channel_id UUID FK → channels,
  app_id UUID,
  config JSONB,                   -- { "repo": "mikalv/msgr", "branch": "main" }
  PRIMARY KEY (channel_id, app_id)
)
```

---

## App Manifest

```json
{
  "schema_version": "1",
  "app": {
    "name": "GitHub",
    "slug": "github",
    "description": "GitHub integration — issues, PRs, notifications",
    "icon": "🐙",
    "developer": "msgr-official"
  },

  "executor": {
    "type": "webhook",
    "url": "https://github-app.msgr.no/webhook",
    "events_url": "https://github-app.msgr.no/events"
  },

  "bot_user": {
    "name": "GitHub Bot",
    "always_online": true
  },

  "slash_commands": [
    {
      "name": "issue",
      "description": "Opprett en GitHub issue",
      "args": "fritekst beskrivelse",
      "permission": "member"
    },
    {
      "name": "pr",
      "description": "List åpne pull requests",
      "args": "[repo]",
      "permission": "member"
    },
    {
      "name": "deploy",
      "description": "Trigger deployment",
      "args": "environment [branch]",
      "permission": "admin"
    }
  ],

  "event_subscriptions": [
    "message.created",
    "channel.created",
    "member.joined"
  ],

  "scopes": [
    "channels:read",
    "channels:write",
    "messages:read",
    "messages:write",
    "profiles:read",
    "commands:register"
  ],

  "channel_binding": {
    "type": "repo",
    "config_schema": {
      "repo": { "type": "string", "required": true, "label": "GitHub repository (owner/repo)" },
      "branch": { "type": "string", "default": "main", "label": "Default branch" },
      "auto_notify": { "type": "boolean", "default": true, "label": "Post PR/issue updates" }
    }
  },

  "required_secrets": [
    {
      "key": "github_token",
      "label": "GitHub Personal Access Token",
      "help": "Needs 'repo' scope. Create at github.com/settings/tokens"
    }
  ],

  "oauth": {
    "provider": "github",
    "scopes": ["repo", "read:org"],
    "redirect_url": "https://github-app.msgr.no/oauth/callback"
  }
}
```

### LLM Executor Manifest (no-code app)

```json
{
  "schema_version": "1",
  "app": {
    "name": "Issue Creator",
    "slug": "issue-creator",
    "description": "AI-powered GitHub issue creation",
    "icon": "🤖"
  },

  "executor": {
    "type": "llm",
    "model": null,
    "system_prompt": "Du er en GitHub-assistent...",
    "tools": ["github.create_issue", "github.list_labels"],
    "max_tokens": 2048,
    "temperature": 0.3
  },

  "slash_commands": [
    {
      "name": "issue",
      "description": "Opprett GitHub issue med AI",
      "args": "beskrivelse av problemet"
    }
  ],

  "required_secrets": ["github_token"],

  "channel_binding": {
    "type": "repo",
    "config_schema": {
      "repo": { "type": "string", "required": true }
    }
  }
}
```

---

## Scopes

| Scope | Description |
|-------|-------------|
| `channels:read` | List and read channel info |
| `channels:write` | Create/update channels |
| `messages:read` | Read messages in channels the app is in |
| `messages:write` | Send messages and replies |
| `profiles:read` | Read team member profiles |
| `commands:register` | Register slash commands |
| `reactions:write` | Add/remove reactions |
| `files:read` | Access uploaded files |
| `files:write` | Upload files |
| `threads:read` | Read thread replies |
| `threads:write` | Post thread replies |
| `presence:read` | See who's online |
| `admin:read` | Read team settings |
| `admin:write` | Modify team settings |

---

## Event System

### Event Dispatch Flow

```
1. Something happens in Msgr (message sent, user joins, etc.)
2. Backend checks: which installed apps subscribe to this event?
3. For each app:
   a. Webhook: POST event to app's webhook URL (async, no timeout)
   b. Bot: event arrives via WebSocket (already connected)
   c. LLM: only triggered by slash commands, not passive events
   d. Builtin: direct function call in BEAM
4. App processes event
5. App responds via Msgr API (webhook/bot) or return value (builtin)
```

### Event Payload

```json
{
  "event_id": "evt_xxx",
  "event_type": "message.created",
  "team_id": "team_xxx",
  "timestamp": "2026-03-21T12:00:00Z",
  "data": {
    "channel_id": "ch_xxx",
    "message": {
      "id": "msg_xxx",
      "content": { "text": "Hello world" },
      "sender_profile_id": "prof_xxx",
      "sender_name": "Mikal"
    }
  },
  "app_config": {
    "repo": "mikalv/msgr"
  }
}
```

### Webhook Signing

```
X-Msgr-Signature: sha256=HMAC(webhook_secret, raw_body)
X-Msgr-Timestamp: 1711234567
X-Msgr-Event: message.created
```

App verifies: `HMAC(secret, timestamp + "." + body) == signature`

---

## Slash Command Execution Flow

```
User types: /issue Fix the login timeout bug

1. Client detects "/" prefix
2. Client shows command autocomplete from cached command list
3. User submits command
4. Client sends to backend:
   POST /api/teams/:slug/channels/:id/commands
   { "command": "issue", "args": "Fix the login timeout bug" }

5. Backend resolves:
   - Is "issue" registered? → Yes, by app "github"
   - Is app installed in this team? → Yes
   - Does user have permission? → Yes (member)
   - Is channel binding required? → Yes (repo)
   - Is channel bound? → Yes (mikalv/msgr)

6. Backend posts "working" message:
   System message: "🤖 Oppretter issue..."

7. Backend dispatches to executor:
   - Webhook: POST to app webhook with command + args + config
   - LLM: Run prompt with tools and channel binding config
   - Builtin: Call module function
   - Bot: Push event via WebSocket

8. Executor runs (async, can take minutes)

9. Executor responds:
   - Posts result message to channel via API
   - Updates command_execution status

10. Channel shows result:
    System message: "✅ Issue #42 created: 'Fix login timeout' — github.com/mikalv/msgr/issues/42"
```

---

## LLM Tool System

For LLM executor mode, tools are predefined server-side functions:

```elixir
defmodule MsgrApps.Tools.GitHub do
  @behaviour MsgrApp.Tool

  def name, do: "github.create_issue"
  def description, do: "Create a GitHub issue"
  def parameters do
    %{
      type: "object",
      properties: %{
        title: %{type: "string", description: "Issue title"},
        body: %{type: "string", description: "Issue body in markdown"},
        labels: %{type: "array", items: %{type: "string"}}
      },
      required: ["title", "body"]
    }
  end

  def execute(%{title: title, body: body, labels: labels}, %{secrets: secrets, config: config}) do
    repo = config["repo"]
    token = secrets["github_token"]
    # Call GitHub API
    {:ok, %{url: "https://github.com/#{repo}/issues/42", number: 42}}
  end
end
```

Tools are registered globally. LLM executor apps reference them by name. This prevents arbitrary code execution — only predefined, audited tools can run.

---

## Bot Token System (Mode C)

Simple alternative to OAuth for internal/custom bots:

```
1. Team admin goes to Settings → Apps → Create Bot
2. Enters bot name, selects scopes
3. System generates token: "mbt_xxxxxxxxxxxx"
4. Admin gives token to bot developer
5. Bot connects:

   final client = MsgrClient(baseUrl: 'https://dev.msgr.no');
   await client.connectWithBotToken('mbt_xxxxxxxxxxxx');
   // Auto-joins configured channels
   // Receives events via WebSocket
```

No OAuth dance. No redirect URLs. Just a token.

Token can be revoked instantly by team admin.

---

## Installation Flow

### For team admin:

```
1. Browse App Directory (or enter app URL)
2. Click "Install"
3. Review required scopes
4. Enter required secrets (GitHub token, etc.)
5. Configure channel bindings (optional)
6. App is active
```

### For app developer:

```
1. Create app manifest (JSON/YAML)
2. Register via API or CLI:
   POST /api/apps { manifest: {...} }
3. Get app_id and webhook secret
4. Implement webhook handler or bot
5. Share app URL with teams
```

---

## Implementation Phases

### Phase 1: Foundation (Backend)
- [ ] Create `apps`, `app_installations`, `slash_commands`, `bot_tokens` tables
- [ ] App CRUD API endpoints
- [ ] Bot token generation and validation
- [ ] Slash command registry and lookup
- [ ] Command execution endpoint: POST /api/teams/:slug/channels/:id/commands

### Phase 2: Built-in Commands (Mode B)
- [ ] Executor framework with behaviour/interface
- [ ] /poll — create polls in channels
- [ ] /remind — set reminders
- [ ] /topic — set channel topic
- [ ] Commands loaded from Flutter via team's installed apps

### Phase 3: LLM Executor (Mode D)
- [ ] LLM executor that runs prompts with tools
- [ ] Tool registry (github.create_issue, etc.)
- [ ] GitHub tool implementation
- [ ] Team LLM config (model, API key via llm_agent package)
- [ ] Async execution with progress messages

### Phase 4: Bot Tokens (Mode C Enhancement)
- [ ] Bot token management UI in team settings
- [ ] Token-based WebSocket auth in UserSocket
- [ ] Bot profile creation on install
- [ ] Scope enforcement on bot actions

### Phase 5: Webhooks (Mode A)
- [ ] Webhook dispatch system
- [ ] Event fanout to subscribed apps
- [ ] Webhook signing and verification
- [ ] Retry logic with exponential backoff
- [ ] App API for posting responses

### Phase 6: App Directory
- [ ] Public app marketplace
- [ ] App review/approval process
- [ ] Usage analytics per app
- [ ] Rating system

### Phase 7: Hosted Bots (Mode E)
- [ ] Sandboxed execution environment (Deno/WASM/gVisor)
- [ ] Code upload and deployment
- [ ] Resource limits and monitoring
- [ ] KV store API for bot state

---

## Security Principles

1. **No arbitrary code execution** — LLM tools and built-in commands are predefined
2. **Scoped access** — Apps can only do what their scopes allow
3. **Encrypted secrets** — API keys stored encrypted at rest
4. **Audit trail** — All command executions logged
5. **Revocable** — Team admin can disable any app instantly
6. **Rate limited** — Per-app, per-command, per-user limits
7. **Signed webhooks** — HMAC verification on all webhook payloads
8. **Bot isolation** — Hosted bots run in sandboxed containers
9. **No network by default** — Hosted bots must whitelist external URLs

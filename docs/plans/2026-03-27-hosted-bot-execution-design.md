# Hosted Bot Execution — Design Specification (#99)

## Overview

A system where developers deploy bot code and Relay hosts and runs it. No server infrastructure needed. Initially internal-only, opens to external developers later.

## Runtimes

- **Deno** (JS/TS) — primary. V8 isolates, native TypeScript, built-in permission system
- **Dart** — secondary. Reuses librelay directly, WebSocket connection to Relay

## Connectivity

- **Deno bots**: stdin/stdout JSON-lines callback. Host pushes events in, reads responses out. Bot is passive.
- **Dart bots**: WebSocket via librelay (same as Kåre). Bot manages own connection.

Runtime is chosen automatically from `relay.app.yaml` manifest.

## Architecture

```
Developer → relay deploy ./bot → Upload API → MinIO storage → Bot Host starts process

Bot Host (Elixir application)
├── BotRegistry (GenServer) — tracks running bots, status, metadata
├── BotSupervisor (DynamicSupervisor) — supervised OS processes
├── BotRunner.Deno — deno run with stdin/stdout protocol
├── BotRunner.Dart — dart run with librelay WebSocket
├── BotEventRouter — subscribes to PubSub, routes events to bot processes
└── BotKV — PostgreSQL JSONB key/value store per bot
```

## Lifecycle

1. Developer runs `relay deploy .` (CLI) or pushes to connected git repo
2. API receives code archive, stores in MinIO under `bots/{app_id}/{version}.tar.gz`
3. Bot Host downloads archive, extracts to temp directory
4. DynamicSupervisor starts OS process (deno/dart)
5. Process runs until crash (auto-restart with backoff) or manual stop
6. Logs stream to OpenObserve

## Manifest (`relay.app.yaml`)

```yaml
name: my-bot
runtime: deno              # deno | dart
entrypoint: bot.ts         # or bin/bot.dart
network: internal          # restricted | internal | unrestricted

triggers:
  - event: message:created
    channels: ["*"]

kv: true

env:
  LLM_MODEL: "qwen3.5-abliterated-35b"
```

## Network Policies

| Policy | Access | Use case |
|--------|--------|----------|
| `restricted` | Relay API only | Third-party bots (default) |
| `internal` | Relay API + LLM proxy + internal services | Our own bots (Kåre etc) |
| `unrestricted` | Everything | Manual approval only |

Enforced via:
- Deno: `--allow-net=<whitelist>`
- Dart: firewall rules / network namespace (future)

## Resource Limits (v1)

- Memory: 128MB per bot (Deno `--v8-flags=--max-old-space-size=128`)
- CPU: OS-level niceness
- Network: per network policy
- Timeout: 30s per event callback (Deno only)
- Auto-restart: backoff 3s → 6s → 12s → 60s max. After 5 crashes in 5 min → status `crashed`, admin notified

## Stdin/Stdout Protocol (Deno bots)

JSON-lines, one message per line:

```
Host → Bot:  {"event": "message:created", "data": {"channel_id": "...", "content": {...}, ...}}
Bot → Host:  {"action": "reply", "channel_id": "...", "content": {"text": "Hello"}}
Bot → Host:  {"method": "kv.set", "key": "count", "value": 42}
Host → Bot:  {"result": "ok"}
Bot → Host:  {"method": "kv.get", "key": "count"}
Host → Bot:  {"result": {"value": 42}}
```

## KV Store

Table: `bot_kv_entries`

```sql
CREATE TABLE bot_kv_entries (
  app_installation_id UUID REFERENCES app_installations(id),
  key TEXT NOT NULL,
  value JSONB NOT NULL,
  expires_at TIMESTAMPTZ,
  PRIMARY KEY (app_installation_id, key)
);
```

Access:
- Deno: via stdin/stdout protocol (kv.get, kv.set, kv.delete)
- Dart: REST API with bot-token auth (GET/PUT/DELETE /api/apps/kv/:key)

Limits: 1000 keys per bot, 100KB per value.

## Developer Experience

### Deno bot example

```typescript
import { onEvent, reply, kv } from "relay/sdk";

onEvent("message:created", async (msg) => {
  if (!msg.content.includes("@mybot")) return;
  const count = await kv.get("msg_count") ?? 0;
  await kv.set("msg_count", count + 1);
  await reply(msg, `Message #${count + 1}!`);
});
```

### Dart bot example

```dart
import 'package:librelay/librelay.dart';

void main() async {
  final bot = RelayBot.fromEnv();
  bot.onMessage((msg) async {
    if (!msg.content.contains('@mybot')) return;
    await bot.reply(msg, 'Hei!');
  });
  await bot.start();
}
```

### CLI

```bash
relay deploy .            # package + upload + start
relay logs my-bot         # stream logs
relay restart my-bot      # restart process
relay stop my-bot         # stop process
relay status              # list running bots
```

## Deploy Flow

### CLI deploy
1. `relay deploy .` reads `relay.app.yaml`
2. Archives project directory (excludes .git, node_modules, .dart_tool)
3. POST /api/apps/:slug/deploy with multipart upload
4. Server stores in MinIO, triggers Bot Host to start/restart

### Git push deploy
1. Developer connects GitHub repo in app settings
2. GitHub webhook fires on push to main
3. Relay clones repo, archives, same flow as CLI

## Phased Rollout

**Phase 1 (internal):**
- BotRunner.Dart only (Kåre migrates to hosted execution)
- Manual deploy via scp + restart
- No CLI, no git integration
- KV store

**Phase 2 (CLI):**
- `relay` CLI tool (Dart or Rust)
- BotRunner.Deno added
- Deploy API + MinIO storage
- Stdin/stdout protocol

**Phase 3 (external):**
- Git push deploy
- Container isolation (gVisor or Firecracker)
- Per-bot resource monitoring dashboard
- Rate limiting on KV and API calls

# Parallel Sprint — 4 Tracks

## Track A: App Platform Phase 1 (Backend)

**Files to create/modify:**
- `backend/apps/msgr/priv/repo/migrations/20260321000001_create_apps.exs`
- `backend/apps/teams/priv/repo/tenant_migrations/20260321000001_create_command_executions.exs`
- `backend/apps/teams/priv/repo/tenant_migrations/20260321000002_create_channel_app_configs.exs`
- `backend/apps/teams/priv/repo/tenant_migrations/20260321000003_add_app_id_to_profiles.exs`
- `backend/apps/msgr/lib/msgr/apps/app.ex` — Ecto schema
- `backend/apps/msgr/lib/msgr/apps/app_installation.ex`
- `backend/apps/msgr/lib/msgr/apps/slash_command.ex`
- `backend/apps/msgr/lib/msgr/apps/bot_token.ex`
- `backend/apps/msgr/lib/msgr/apps.ex` — context module
- `backend/apps/msgr_web/lib/msgr_web/controllers/app_controller.ex`
- `backend/apps/msgr_web/lib/msgr_web/controllers/command_controller.ex`
- `backend/apps/msgr_web/lib/msgr_web/router.ex` — add routes

**Depends on:** Nothing — standalone backend work
**Touches:** Only backend/ directory

### Tasks:
1. Create public schema migrations (apps, app_installations, slash_commands, bot_tokens)
2. Create tenant schema migrations (command_executions, channel_app_configs, add app_id to profiles)
3. Create Ecto schemas for all new tables
4. Create Apps context module (CRUD, install, lookup)
5. Create CommandController (POST /api/teams/:slug/channels/:id/commands)
6. Create AppController (CRUD + install + token management)
7. Add routes to router
8. Create executor behaviour
9. Register 3 built-in commands on app startup (/poll, /remind, /topic)
10. Deploy and run migrations on server

---

## Track B: File Sharing #79 (Flutter + Backend)

**Files to create/modify:**
- `flutter_frontend/packages/libmsgr/lib/src/api/msgr_api_client.dart` — add upload methods
- `flutter_frontend/packages/core/lib/providers/models.dart` — add FileAttachment model
- `flutter_frontend/packages/core/lib/ui/shell/simple_chat_content.dart` — render file/image attachments
- `backend/apps/msgr_web/lib/msgr_web/controllers/team_media_controller.ex` — presigned URLs

**Depends on:** Nothing — standalone
**Touches:** libmsgr API, message rendering, backend media controller

### Tasks:
1. Backend: Verify presign endpoint works with MinIO (already partially implemented)
2. libmsgr: Add `uploadFile(teamSlug, channelId, file)` — gets presigned URL, uploads to MinIO
3. libmsgr: Add `getFileUrl(objectKey)` — gets presigned download URL
4. Flutter: Wire composer attachment button to file picker → upload → send message with media_refs
5. Flutter: Render image attachments inline (thumbnail, click to expand)
6. Flutter: Render file attachments as download cards (icon, name, size)
7. Flutter: Paste image from clipboard → auto-upload
8. Flutter: Drag-and-drop files onto chat area (composer already has DropTarget)
9. 50 MB file size limit validation

---

## Track C: JWT Auth #89 (Backend + Flutter)

**Files to create/modify:**
- `backend/apps/auth_provider/lib/auth_provider/guardian.ex` — already exists, configure
- `backend/apps/msgr/lib/msgr/auth.ex` — issue JWT on verify
- `backend/apps/msgr_web/lib/msgr_web/channels/user_socket.ex` — accept JWT
- `backend/apps/msgr_web/lib/msgr_web/plugs/session_context.ex` — validate JWT
- `backend/config/runtime.exs` — Guardian secret config
- `flutter_frontend/packages/libmsgr/lib/src/api/msgr_api_client.dart` — use Bearer token
- `flutter_frontend/packages/core/lib/providers/auth_state_provider.dart` — store token

**Depends on:** AuthProvider.Repo configured (already done)
**Touches:** Auth flow end-to-end

### Tasks:
1. Backend: Configure Guardian secret in runtime.exs
2. Backend: On verify_challenge success, issue JWT with account_id, profile_id, teams
3. Backend: Return access_token + refresh_token in verify response
4. Backend: SessionContext plug validates JWT (Authorization: Bearer) as primary, fall back to X-headers
5. Backend: UserSocket accepts JWT as connection param
6. Backend: Refresh endpoint: POST /api/v1/auth/refresh
7. Backend: Include team memberships in JWT claims
8. libmsgr: Store tokens in MsgrApiClient
9. libmsgr: Auto-attach Authorization header
10. libmsgr: Token refresh logic (refresh when access_token expires)
11. Flutter: Store tokens in SharedPreferences (encrypted)
12. Flutter: Update login flow to use returned tokens
13. Deploy and test end-to-end

---

## Track D: Desktop Polish #75 (Flutter only)

**Files to create/modify:**
- `flutter_frontend/packages/core/lib/ui/shell/quick_switcher.dart` — NEW
- `flutter_frontend/lib/desktop/macos.dart` — native menus, keyboard shortcuts
- `flutter_frontend/packages/core/lib/ui/shell/app_shell.dart` — Cmd+K binding

**Depends on:** Nothing — standalone Flutter work
**Touches:** Only Flutter UI, no backend

### Tasks:
1. Quick Switcher (Cmd+K): Modal overlay with search field
   - Search channels, DMs, and teams
   - Keyboard navigation (up/down/enter/escape)
   - Recent items at top
   - Fuzzy matching on names
2. macOS native menu bar (File, Edit, View, Window, Help)
   - Edit: Undo, Redo, Cut, Copy, Paste, Select All
   - View: Toggle Sidebar, Toggle Members
   - Window: Minimize, Zoom
3. Keyboard shortcuts:
   - Cmd+K: Quick switcher
   - Cmd+N: New message/DM
   - Cmd+Shift+N: New channel
   - Cmd+[/]: Navigation history
   - Cmd+1-9: Switch to team by index
   - Escape: Close panels (thread, members)
4. Desktop notifications (macOS native)
5. Dock badge with unread count

---

## Parallelization Matrix

```
Track A (App Platform)  — backend only, no Flutter
Track B (File Sharing)  — libmsgr + Flutter + backend media
Track C (JWT Auth)      — backend auth + libmsgr + Flutter auth
Track D (Desktop Polish) — Flutter UI only

Conflicts:
  A ↔ B: None (different backend areas)
  A ↔ C: Both touch router.ex (minor, different scopes)
  A ↔ D: None
  B ↔ C: Both touch libmsgr API client (B adds upload, C adds auth headers)
  B ↔ D: None
  C ↔ D: None

Safe parallel groups:
  Group 1: A + D (zero overlap)
  Group 2: B + C (minor overlap in libmsgr, manageable)

  OR: All four simultaneously if we're careful with libmsgr edits
```

# App Marketplace Implementation Plan (#98)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build an in-app marketplace where team admins can browse, install, configure, and manage apps with per-channel settings.

**Architecture:** Extends existing App/AppInstallation schemas with new fields (category, config_schema, etc). Adds directory endpoint + channel metadata column. Flutter UI lives in Team Settings as an "Apps" tab with browse/detail/installed views.

**Tech Stack:** Elixir/Phoenix (backend), Flutter/Riverpod (frontend), PostgreSQL JSONB (config schemas)

---

### Task 1: Backend — Extend App schema with marketplace fields

**Files:**
- Modify: `backend/apps/msgr/lib/msgr/apps/app.ex`
- Create: `backend/apps/msgr/priv/repo/migrations/20260327100001_add_marketplace_fields_to_apps.exs`

**Step 1: Create migration**

```elixir
defmodule Messngr.Repo.Migrations.AddMarketplaceFieldsToApps do
  use Ecto.Migration

  def change do
    alter table(:apps) do
      add :category, :text, default: "custom"
      add :featured, :boolean, default: false
      add :install_count, :integer, default: 0
      add :config_schema, :map, default: %{}
      add :channel_config_schema, :map, default: %{}
      add :required_scopes, {:array, :text}, default: []
    end

    create index(:apps, [:category])
    create index(:apps, [:featured])
  end
end
```

**Step 2: Update App schema**

Add fields to `app.ex`:
- `field :category, :string, default: "custom"`
- `field :featured, :boolean, default: false`
- `field :install_count, :integer, default: 0`
- `field :config_schema, :map, default: %{}`
- `field :channel_config_schema, :map, default: %{}`
- `field :required_scopes, {:array, :string}, default: []`

Update `changeset/2` to cast the new fields.

**Step 3: Commit**

```bash
git commit -m "feat: add marketplace fields to App schema (category, config_schema, scopes)"
```

---

### Task 2: Backend — Channel metadata column

**Files:**
- Modify: `backend/apps/teams/lib/teams/tenant_models/channel.ex`
- Create: `backend/apps/teams/priv/repo/tenant_migrations/20260327100002_add_metadata_to_channels.exs`

**Step 1: Create tenant migration**

```elixir
defmodule Teams.Repo.TenantMigrations.AddMetadataToChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      add :metadata, :map, default: %{}
    end
  end
end
```

**Step 2: Add field to Channel schema**

In `channel.ex`, add: `field :metadata, :map, default: %{}`
Update changeset to cast `:metadata`.

**Step 3: Commit**

```bash
git commit -m "feat: add metadata JSONB column to channels for app-specific settings"
```

---

### Task 3: Backend — Directory endpoint + app detail

**Files:**
- Modify: `backend/apps/msgr_web/lib/msgr_web/controllers/app_controller.ex`
- Modify: `backend/apps/msgr_web/lib/msgr_web/router.ex`
- Modify: `backend/apps/msgr/lib/msgr/apps.ex`

**Step 1: Add directory functions to Apps context**

```elixir
def list_directory(opts \\ []) do
  import Ecto.Query
  query = from(a in App, where: a.visibility == "public" and a.status == "active",
    order_by: [desc: a.featured, desc: a.install_count])

  query = case Keyword.get(opts, :category) do
    nil -> query
    cat -> from(a in query, where: a.category == ^cat)
  end

  query = case Keyword.get(opts, :q) do
    nil -> query
    q -> from(a in query, where: ilike(a.name, ^"%#{q}%") or ilike(a.description, ^"%#{q}%"))
  end

  Repo.all(query)
end

def increment_install_count(app_id) do
  import Ecto.Query
  from(a in App, where: a.id == ^app_id)
  |> Repo.update_all(inc: [install_count: 1])
end
```

**Step 2: Add controller actions**

```elixir
def directory(conn, params) do
  apps = Apps.list_directory(
    category: params["category"],
    q: params["q"]
  )
  json(conn, %{data: Enum.map(apps, &app_detail_json/1)})
end

def show(conn, %{"slug" => slug}) do
  case Apps.get_app_by_slug(slug) do
    nil -> {:error, :not_found}
    app -> json(conn, %{data: app_detail_json(app)})
  end
end

defp app_detail_json(app) do
  app_json(app)
  |> Map.merge(%{
    category: app.category,
    featured: app.featured,
    install_count: app.install_count,
    config_schema: app.config_schema,
    channel_config_schema: app.channel_config_schema,
    required_scopes: app.required_scopes,
    description: app.description,
    webhook_url: if(app.webhook_url, do: "[configured]")
  })
end
```

**Step 3: Add routes**

In the public `/api/apps` scope:
```elixir
get "/directory", AppController, :directory
get "/directory/:slug", AppController, :show
```

**Step 4: Update `install` to increment count**

After successful install, call `Apps.increment_install_count(app.id)`.

**Step 5: Commit**

```bash
git commit -m "feat: app directory endpoint with search, category filter, and detail view"
```

---

### Task 4: Backend — Channel app config endpoints

**Files:**
- Modify: `backend/apps/msgr_web/lib/msgr_web/controllers/team_channel_controller.ex`
- Modify: `backend/apps/msgr_web/lib/msgr_web/router.ex`

**Step 1: Add get/put channel app config**

```elixir
def get_app_config(conn, %{"channel_id" => channel_id, "app_slug" => app_slug}) do
  prefix = conn.assigns.tenant_prefix
  case Channels.get_channel(prefix, channel_id) do
    nil -> {:error, :not_found}
    channel ->
      config = get_in(channel.metadata || %{}, ["apps", app_slug]) || %{}
      json(conn, %{data: config})
  end
end

def update_app_config(conn, %{"channel_id" => channel_id, "app_slug" => app_slug} = params) do
  prefix = conn.assigns.tenant_prefix
  case Channels.get_channel(prefix, channel_id) do
    nil -> {:error, :not_found}
    channel ->
      metadata = channel.metadata || %{}
      apps = Map.get(metadata, "apps", %{})
      updated_apps = Map.put(apps, app_slug, params["config"] || %{})
      updated_metadata = Map.put(metadata, "apps", updated_apps)

      case Channels.update_channel(prefix, channel, %{metadata: updated_metadata}) do
        {:ok, ch} -> json(conn, %{data: get_in(ch.metadata, ["apps", app_slug])})
        {:error, changeset} -> {:error, changeset}
      end
  end
end
```

**Step 2: Add routes (team-scoped, tenant-resolved)**

```elixir
get "/channels/:channel_id/apps/:app_slug/config", TeamChannelController, :get_app_config
put "/channels/:channel_id/apps/:app_slug/config", TeamChannelController, :update_app_config
```

**Step 3: Commit**

```bash
git commit -m "feat: per-channel app config endpoints (get/put metadata.apps.<slug>)"
```

---

### Task 5: libmsgr — API client methods

**Files:**
- Modify: `flutter_frontend/packages/libmsgr/lib/src/api/msgr_api_client.dart`

**Step 1: Add marketplace API methods**

```dart
/// GET /api/apps/directory — browse public apps
Future<List<Map<String, dynamic>>> getAppDirectory({String? category, String? query}) async {
  final params = <String, String>{};
  if (category != null) params['category'] = category;
  if (query != null) params['q'] = query;
  final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
  final res = await get('/api/apps/directory${qs.isNotEmpty ? '?$qs' : ''}');
  final data = res['data'];
  if (data is List) return data.cast<Map<String, dynamic>>();
  return [];
}

/// GET /api/apps/directory/:slug — app detail
Future<Map<String, dynamic>> getAppDetail(String slug) async {
  final res = await get('/api/apps/directory/$slug');
  return res['data'] as Map<String, dynamic>? ?? res;
}

/// POST /api/teams/:slug/apps/:app_slug/install — install app
Future<Map<String, dynamic>> installApp(String teamSlug, String appSlug, {Map<String, dynamic>? config}) async {
  return post('/api/teams/$teamSlug/apps/$appSlug/install', body: {
    if (config != null) 'config': config,
  });
}

/// DELETE /api/teams/:slug/apps/:app_slug — uninstall
Future<void> uninstallApp(String teamSlug, String appSlug) async {
  await delete('/api/teams/$teamSlug/apps/$appSlug');
}

/// GET /api/teams/:slug/channels/:id/apps/:app_slug/config
Future<Map<String, dynamic>> getChannelAppConfig(String teamSlug, String channelId, String appSlug) async {
  final res = await get('/api/teams/$teamSlug/channels/$channelId/apps/$appSlug/config');
  return res['data'] as Map<String, dynamic>? ?? {};
}

/// PUT /api/teams/:slug/channels/:id/apps/:app_slug/config
Future<void> updateChannelAppConfig(String teamSlug, String channelId, String appSlug, Map<String, dynamic> config) async {
  await put('/api/teams/$teamSlug/channels/$channelId/apps/$appSlug/config', body: {'config': config});
}
```

**Step 2: Commit**

```bash
git commit -m "feat: libmsgr API methods for app directory, install, and channel config"
```

---

### Task 6: Flutter — Apps tab in Team Settings (Browse view)

**Files:**
- Modify: `flutter_frontend/packages/core/lib/ui/settings/settings_page.dart`

**Step 1: Add "Apps" tab to _TeamAdminSection**

Update `TabController` length from 3 to 4. Add `Tab(text: 'Apps')` and `_buildAppsTab()` method.

**Step 2: Build browse view**

```dart
Widget _buildAppsTab() {
  return _AppMarketplaceTab();
}
```

Create `_AppMarketplaceTab` as a separate `ConsumerStatefulWidget` with:
- `_view` state: `browse` | `installed`
- Toggle chips at top: "Browse" / "Installed"
- Search field
- Category filter chips: All, Developer Tools, Productivity, Communication, Calendar
- Grid/list of app cards loaded from `getAppDirectory()`
- Each card: icon placeholder, name, description, install count, Install/Installed badge

**Step 3: App card widget**

```dart
class _AppCard extends StatelessWidget {
  // icon, name, description, installCount, isInstalled, onTap
}
```

**Step 4: Commit**

```bash
git commit -m "feat: apps browse tab in team settings with search and category filter"
```

---

### Task 7: Flutter — App detail dialog with install flow

**Files:**
- Modify: `flutter_frontend/packages/core/lib/ui/settings/settings_page.dart`

**Step 1: Build detail dialog**

Triggered when tapping an app card. Shows:
- App name + description
- Required scopes with icons
- Config form auto-generated from `config_schema`:
  - `string` → TextField
  - `secret` → TextField with obscureText
  - `boolean` → Switch
  - `select` → DropdownButton
  - `url` → TextField with URL keyboard
- Channel binding multi-select (load from channelListProvider)
- Install button

**Step 2: Config form builder**

```dart
Widget _buildConfigForm(Map<String, dynamic> schema, Map<String, dynamic> values, void Function(String, dynamic) onChanged) {
  return Column(
    children: schema.entries.map((entry) {
      final key = entry.key;
      final field = entry.value as Map<String, dynamic>;
      final type = field['type'] as String?;
      final label = field['label'] as String? ?? key;
      // ... switch on type to build appropriate widget
    }).toList(),
  );
}
```

**Step 3: Install action**

On install: call `installApp()` with collected config + selected channel IDs. Show success snackbar. Refresh installed apps list.

**Step 4: Commit**

```bash
git commit -m "feat: app detail dialog with scope review, config form, channel binding, and install"
```

---

### Task 8: Flutter — Installed apps management

**Files:**
- Modify: `flutter_frontend/packages/core/lib/ui/settings/settings_page.dart`

**Step 1: Build installed view**

Toggled via "Installed" chip. Shows:
- List of installed apps from `getInstalledApps()`
- Per app: name, status badge (active/paused), actions menu
- Actions: Edit config, Change channels, View tokens, Uninstall

**Step 2: Edit config dialog**

Reuses the same `_buildConfigForm` from Task 7. Pre-populates with current `installation.config`.

**Step 3: Uninstall confirmation**

Simple confirm dialog → calls `uninstallApp()` → refresh list.

**Step 4: Commit**

```bash
git commit -m "feat: installed apps management with edit config and uninstall"
```

---

### Task 9: Flutter — Channel Settings > Apps tab

**Files:**
- Modify: `flutter_frontend/packages/core/lib/ui/shell/channel_settings_panel.dart`

**Step 1: Add "Apps" tab to channel settings**

Update `TabController` length from 3 to 4. Add `Tab(text: 'Apps')`.

**Step 2: Build channel apps config view**

For each installed app that has `channel_config_schema`:
- Show app name + icon
- Auto-generated form from `channel_config_schema`
- Save button → calls `updateChannelAppConfig()`
- Load current values from `getChannelAppConfig()`

**Step 3: Commit**

```bash
git commit -m "feat: per-channel app configuration tab in channel settings"
```

---

### Task 10: Seed first-party apps

**Files:**
- Create: `backend/apps/msgr/priv/repo/seeds_apps.exs` (or add to existing seeds)

**Step 1: Seed built-in apps**

```elixir
# GitHub integration
Apps.create_app(%{
  slug: "github",
  name: "GitHub",
  description: "Get notifications for PRs, issues, and deployments. Use /issue to create issues.",
  category: "developer-tools",
  executor_type: "webhook",
  visibility: "public",
  featured: true,
  required_scopes: ["messages:write", "channels:read"],
  config_schema: %{
    "token" => %{"type" => "secret", "label" => "GitHub Personal Access Token", "required" => true},
    "repo" => %{"type" => "string", "label" => "Default repository (owner/name)", "placeholder" => "mikalv/relay"}
  },
  channel_config_schema: %{
    "repo" => %{"type" => "string", "label" => "Repository for this channel"},
    "notify_prs" => %{"type" => "boolean", "label" => "Notify on pull requests", "default" => true},
    "notify_issues" => %{"type" => "boolean", "label" => "Notify on issues", "default" => true}
  }
})

# Calendar (JMAP)
Apps.create_app(%{
  slug: "calendar",
  name: "Calendar",
  description: "JMAP calendar integration. Get event reminders and manage schedules from chat.",
  category: "calendar",
  executor_type: "builtin",
  visibility: "public",
  featured: true,
  required_scopes: ["messages:write"],
  config_schema: %{
    "jmap_url" => %{"type" => "url", "label" => "JMAP Server URL", "required" => true},
    "jmap_token" => %{"type" => "secret", "label" => "JMAP Auth Token", "required" => true}
  },
  channel_config_schema: %{
    "calendar_id" => %{"type" => "string", "label" => "Calendar ID"},
    "remind_before" => %{"type" => "select", "label" => "Remind before event", "options" => ["5 min", "15 min", "30 min", "1 hour"], "default" => "15 min"}
  }
})
```

**Step 2: Commit**

```bash
git commit -m "feat: seed GitHub and Calendar apps in marketplace"
```

---

## Task Dependencies

```
Task 1 (App schema) ──┐
Task 2 (Channel meta) ┤
                       ├── Task 3 (Directory API) ── Task 5 (libmsgr) ── Task 6 (Browse UI) ── Task 7 (Install UI) ── Task 8 (Installed UI)
Task 4 (Channel API) ─┘                                                                                               │
                                                                                                          Task 9 (Channel Apps tab)
                                                                                                                       │
                                                                                                          Task 10 (Seed apps)
```

Tasks 1, 2, 4 can run in parallel. Tasks 6-8 are sequential. Task 9 depends on Task 4. Task 10 is last.

# UI Polish Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Professional Slack-quality UI with centralized theme system, real profile avatars, sidebar polish, and basic thread support.

**Architecture:** Replace hardcoded `ShellTheme`/`ChatTheme` with `MsgrTheme` InheritedWidget providing semantic color tokens and dimensions. Add `ProfileAvatar` widget with Gravatar fallback. Polish sidebar with border/contrast. Add backend avatar_url field and upload endpoint. Build thread panel reusing flat message layout.

**Tech Stack:** Flutter (Dart), Elixir/Phoenix backend, MinIO S3, Gravatar API, cached_network_image, crypto (for MD5)

---

### Task 1: Theme System — Color Tokens

**Files:**
- Create: `flutter_frontend/packages/core/lib/ui/theme/msgr_color_tokens.dart`

**Step 1: Create the color tokens class**

```dart
import 'dart:ui';

class MsgrColorTokens {
  const MsgrColorTokens({
    required this.sidebarBg,
    required this.sidebarItemActive,
    required this.sidebarItemHover,
    required this.sidebarText,
    required this.sidebarTextBright,
    required this.contentBg,
    required this.contentBorder,
    required this.messageHover,
    required this.messageAuthorName,
    required this.messageText,
    required this.messageTimestamp,
    required this.headerBg,
    required this.headerBorder,
    required this.accent,
    required this.unreadBadge,
    required this.onlineDot,
    required this.teamRailBg,
  });

  final Color sidebarBg;
  final Color sidebarItemActive;
  final Color sidebarItemHover;
  final Color sidebarText;
  final Color sidebarTextBright;
  final Color contentBg;
  final Color contentBorder;
  final Color messageHover;
  final Color messageAuthorName;
  final Color messageText;
  final Color messageTimestamp;
  final Color headerBg;
  final Color headerBorder;
  final Color accent;
  final Color unreadBadge;
  final Color onlineDot;
  final Color teamRailBg;

  static const dark = MsgrColorTokens(
    sidebarBg: Color(0xFF1A1D21),
    sidebarItemActive: Color(0xFF1164A3),
    sidebarItemHover: Color(0x0FFFFFFF),  // 6% white
    sidebarText: Color(0xFFD1D2D3),
    sidebarTextBright: Color(0xFFFFFFFF),
    contentBg: Color(0xFF222529),
    contentBorder: Color(0xFF2E3035),
    messageHover: Color(0x0AFFFFFF),  // 4% white
    messageAuthorName: Color(0xFF4FC3F7), // overridden per-user
    messageText: Color(0xFFE8E8E8),
    messageTimestamp: Color(0x59FFFFFF),  // 35% white
    headerBg: Color(0xFF222529),
    headerBorder: Color(0xFF2E3035),
    accent: Color(0xFF1164A3),
    unreadBadge: Color(0xFFE01E5A),
    onlineDot: Color(0xFF2BAC76),
    teamRailBg: Color(0xFF0F0F10),
  );
}
```

**Step 2: Commit**

```bash
git add flutter_frontend/packages/core/lib/ui/theme/msgr_color_tokens.dart
git commit -m "feat(theme): add MsgrColorTokens with dark theme defaults"
```

---

### Task 2: Theme System — Dimensions

**Files:**
- Create: `flutter_frontend/packages/core/lib/ui/theme/msgr_dimensions.dart`

**Step 1: Create the dimensions class**

```dart
class MsgrDimensions {
  const MsgrDimensions._();

  // Message layout
  static const messageAvatarSize = 36.0;
  static const messageAvatarSizeMobile = 32.0;
  static const messageAvatarSlot = 46.0; // avatar + gap
  static const messageGroupSpacing = 2.0;
  static const messageNewGroupSpacing = 16.0;
  static const messageHorizontalPadding = 20.0;
  static const messageVerticalPadding = 2.0;

  // Sidebar
  static const sidebarWidth = 260.0;
  static const sidebarItemHeight = 28.0;
  static const sidebarAvatarSize = 20.0;
  static const sidebarProfileAvatarSize = 28.0;
  static const teamRailWidth = 56.0;

  // Header
  static const headerHeight = 52.0;

  // General
  static const itemBorderRadius = 6.0;
  static const avatarRadius = 18.0;

  // Thread panel
  static const threadPanelWidth = 400.0;
}
```

**Step 2: Commit**

```bash
git add flutter_frontend/packages/core/lib/ui/theme/msgr_dimensions.dart
git commit -m "feat(theme): add MsgrDimensions constants"
```

---

### Task 3: Theme System — MsgrTheme InheritedWidget

**Files:**
- Create: `flutter_frontend/packages/core/lib/ui/theme/msgr_theme.dart`

**Step 1: Create the theme provider widget**

```dart
import 'package:flutter/material.dart';
import 'msgr_color_tokens.dart';
export 'msgr_color_tokens.dart';
export 'msgr_dimensions.dart';

class MsgrTheme extends InheritedWidget {
  const MsgrTheme({
    super.key,
    required this.colors,
    required super.child,
  });

  final MsgrColorTokens colors;

  static MsgrColorTokens of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<MsgrTheme>();
    return widget?.colors ?? MsgrColorTokens.dark;
  }

  /// Convenience — returns tokens without registering dependency.
  static MsgrColorTokens read(BuildContext context) {
    final widget = context.getInheritedWidgetOfExactType<MsgrTheme>();
    return widget?.colors ?? MsgrColorTokens.dark;
  }

  @override
  bool updateShouldNotify(MsgrTheme oldWidget) => colors != oldWidget.colors;
}
```

**Step 2: Wrap AppShell with MsgrTheme in the app root**

In `flutter_frontend/packages/core/lib/ui/shell/app_shell.dart`, wrap the top-level widget:

Find the `build` method's return and wrap the outermost widget with:
```dart
return MsgrTheme(
  colors: MsgrColorTokens.dark,
  child: /* existing widget tree */,
);
```

Add import: `import 'package:core/ui/theme/msgr_theme.dart';`

**Step 3: Commit**

```bash
git add flutter_frontend/packages/core/lib/ui/theme/msgr_theme.dart
git add flutter_frontend/packages/core/lib/ui/shell/app_shell.dart
git commit -m "feat(theme): add MsgrTheme InheritedWidget, wire into AppShell"
```

---

### Task 4: Migrate ShellTheme References to MsgrTheme

**Files:**
- Modify: `flutter_frontend/packages/core/lib/ui/shell/channel_sidebar.dart`
- Modify: `flutter_frontend/packages/core/lib/ui/shell/channel_list_item.dart`
- Modify: `flutter_frontend/packages/core/lib/ui/shell/dm_list_item.dart`
- Modify: `flutter_frontend/packages/core/lib/ui/shell/team_rail.dart`
- Modify: `flutter_frontend/packages/core/lib/ui/shell/simple_chat_content.dart`
- Keep: `flutter_frontend/packages/core/lib/ui/shell/shell_theme.dart` (delete after all refs migrated)

**Step 1: Replace all `ShellTheme.xxx` with `MsgrTheme.of(context).xxx`**

For each file, replace the static `ShellTheme` references:
- `ShellTheme.sidebarBg` → `MsgrTheme.of(context).sidebarBg`
- `ShellTheme.sidebarText` → `MsgrTheme.of(context).sidebarText`
- `ShellTheme.sidebarTextBright` → `MsgrTheme.of(context).sidebarTextBright`
- `ShellTheme.sidebarActiveItem` → `MsgrTheme.of(context).sidebarItemActive`
- `ShellTheme.sidebarHoverItem` → `MsgrTheme.of(context).sidebarItemHover`
- `ShellTheme.accentColor` → `MsgrTheme.of(context).accent`
- `ShellTheme.unreadBadge` → `MsgrTheme.of(context).unreadBadge`
- `ShellTheme.onlineDot` → `MsgrTheme.of(context).onlineDot`
- `ShellTheme.teamRailBg` → `MsgrTheme.of(context).teamRailBg`
- `ShellTheme.sidebarWidth` → `MsgrDimensions.sidebarWidth`
- `ShellTheme.teamRailWidth` → `MsgrDimensions.teamRailWidth`

Note: Widgets using `const` constructors with ShellTheme colors will need to become non-const since `MsgrTheme.of(context)` requires context. Store the tokens in a local variable at the top of `build`:
```dart
final t = MsgrTheme.of(context);
```

**Step 2: Delete `shell_theme.dart`**

**Step 3: Run `flutter analyze` to catch any remaining refs**

```bash
cd flutter_frontend && flutter analyze packages/core/lib/ui/shell/ 2>&1 | grep -i error
```

**Step 4: Commit**

```bash
git add -A flutter_frontend/packages/core/lib/ui/
git commit -m "refactor(theme): migrate ShellTheme to MsgrTheme tokens"
```

---

### Task 5: ProfileAvatar Widget

**Files:**
- Create: `flutter_frontend/packages/core/lib/ui/widgets/profile_avatar.dart`

**Step 1: Add `crypto` dependency for MD5 (Gravatar)**

Check if `crypto` is in pubspec.yaml for core package. If not:
```yaml
# flutter_frontend/packages/core/pubspec.yaml
dependencies:
  crypto: ^3.0.0
  cached_network_image: ^3.3.0
```

Run: `cd flutter_frontend && flutter pub get`

**Step 2: Create ProfileAvatar widget**

```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:core/ui/theme/msgr_theme.dart';

/// Deterministic color from profile ID hash.
Color _avatarColor(String id) {
  const palette = [
    Color(0xFF4FC3F7), Color(0xFF81C784), Color(0xFFFFB74D),
    Color(0xFFBA68C8), Color(0xFFE57373), Color(0xFF4DD0E1),
    Color(0xFFFFF176), Color(0xFFA1887F), Color(0xFF90A4AE),
    Color(0xFFF06292),
  ];
  var hash = 0;
  for (var i = 0; i < id.length; i++) {
    hash = id.codeUnitAt(i) + ((hash << 5) - hash);
  }
  return palette[hash.abs() % palette.length];
}

String? _gravatarUrl(String? email, {int size = 72}) {
  if (email == null || email.isEmpty) return null;
  final hash = md5.convert(utf8.encode(email.trim().toLowerCase())).toString();
  return 'https://gravatar.com/avatar/$hash?d=404&s=$size';
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.profileId,
    required this.displayName,
    this.avatarUrl,
    this.email,
    this.size = 36,
    this.showOnlineIndicator = false,
    this.isOnline = false,
  });

  final String profileId;
  final String displayName;
  final String? avatarUrl;
  final String? email;
  final double size;
  final bool showOnlineIndicator;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final radius = size / 2;
    final color = _avatarColor(profileId);
    final letter = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : '?';

    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: color.withOpacity(0.25),
      child: Text(
        letter,
        style: TextStyle(
          color: color,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    final imageUrl = avatarUrl ?? _gravatarUrl(email, size: (size * 2).toInt());

    Widget avatar;
    if (imageUrl != null) {
      avatar = CachedNetworkImage(
        imageUrl: imageUrl,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: radius,
          backgroundImage: imageProvider,
        ),
        errorWidget: (context, url, error) => fallback,
        placeholder: (context, url) => fallback,
      );
    } else {
      avatar = fallback;
    }

    if (!showOnlineIndicator) return avatar;

    final t = MsgrTheme.of(context);
    final dotSize = size * 0.3;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: isOnline ? t.onlineDot : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(
                  color: t.sidebarBg,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 3: Commit**

```bash
git add flutter_frontend/packages/core/lib/ui/widgets/profile_avatar.dart
git add flutter_frontend/packages/core/pubspec.yaml
git commit -m "feat(ui): add ProfileAvatar widget with Gravatar + letter fallback"
```

---

### Task 6: Wire ProfileAvatar into Message Rows

**Files:**
- Modify: `flutter_frontend/packages/core/lib/ui/shell/simple_chat_content.dart`

**Step 1: Replace CircleAvatar in _MessageRow with ProfileAvatar**

In `_MessageRowState.build`, find the `CircleAvatar` (around line 886) and replace with:

```dart
ProfileAvatar(
  profileId: msg.senderProfileId,
  displayName: msg.senderName,
  avatarUrl: msg.senderAvatarUrl,  // add to SlackMessage model
  email: msg.senderEmail,          // add to SlackMessage model
  size: MsgrDimensions.messageAvatarSize,
),
```

Add import: `import 'package:core/ui/widgets/profile_avatar.dart';`
Add import: `import 'package:core/ui/theme/msgr_theme.dart';`

**Step 2: Add `senderAvatarUrl` and `senderEmail` to SlackMessage model**

In `flutter_frontend/packages/core/lib/providers/models.dart`, find the `SlackMessage` class and add:
```dart
final String? senderAvatarUrl;
final String? senderEmail;
```

Update the constructor and the `fromJson`/`fromApiMap` factory to read these fields from the profile data.

**Step 3: Commit**

```bash
git add flutter_frontend/packages/core/lib/ui/shell/simple_chat_content.dart
git add flutter_frontend/packages/core/lib/providers/models.dart
git commit -m "feat(ui): wire ProfileAvatar into message rows"
```

---

### Task 7: Sidebar Polish — Border, Colors, Selected State

**Files:**
- Modify: `flutter_frontend/packages/core/lib/ui/shell/app_shell.dart`
- Modify: `flutter_frontend/packages/core/lib/ui/shell/channel_list_item.dart`
- Modify: `flutter_frontend/packages/core/lib/ui/shell/channel_sidebar.dart`

**Step 1: Add 1px border between sidebar and content**

In `app_shell.dart`, where the sidebar and content are laid out in a `Row`, add a `Container` divider:

```dart
Row(
  children: [
    TeamRail(...),
    ChannelSidebar(...),
    Container(width: 1, color: MsgrTheme.of(context).contentBorder),
    Expanded(child: Container(
      color: MsgrTheme.of(context).contentBg,
      child: widget.child,
    )),
  ],
)
```

**Step 2: Update ChannelListItem selected color**

In `channel_list_item.dart`, change the selected background:
```dart
color: isSelected ? t.sidebarItemActive : null,  // was ShellTheme.sidebarActiveItem
```

This uses the new accent blue (`#1164A3`) instead of the old dark gray.

**Step 3: Set content area background**

The main content area (wrapping `SimpleChatContent`) should have `color: MsgrTheme.of(context).contentBg`.

**Step 4: Commit**

```bash
git add flutter_frontend/packages/core/lib/ui/shell/
git commit -m "feat(ui): sidebar polish — border, accent-blue selection, content bg"
```

---

### Task 8: Channel Header Redesign

**Files:**
- Create: `flutter_frontend/packages/core/lib/ui/shell/channel_header.dart`
- Modify: `flutter_frontend/packages/core/lib/ui/shell/simple_chat_content.dart`

**Step 1: Create ChannelHeader widget**

```dart
import 'package:flutter/material.dart';
import 'package:core/ui/theme/msgr_theme.dart';

class ChannelHeader extends StatelessWidget {
  const ChannelHeader({
    super.key,
    required this.channelName,
    this.topic,
    this.isPrivate = false,
    this.onSearchTap,
    this.onMembersTap,
    this.onPinTap,
    this.onSettingsTap,
  });

  final String channelName;
  final String? topic;
  final bool isPrivate;
  final VoidCallback? onSearchTap;
  final VoidCallback? onMembersTap;
  final VoidCallback? onPinTap;
  final VoidCallback? onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final t = MsgrTheme.of(context);

    return Container(
      height: MsgrDimensions.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: t.headerBg,
        border: Border(
          bottom: BorderSide(color: t.headerBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${isPrivate ? "\u{1F512} " : "# "}$channelName',
            style: TextStyle(
              color: t.sidebarTextBright,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (topic != null && topic!.isNotEmpty) ...[
            const SizedBox(width: 12),
            Container(width: 1, height: 20, color: t.contentBorder),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                topic!,
                style: TextStyle(color: t.messageTimestamp, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            const Spacer(),
          _HeaderIcon(Icons.search, onTap: onSearchTap),
          _HeaderIcon(Icons.people_outline, onTap: onMembersTap),
          _HeaderIcon(Icons.push_pin_outlined, onTap: onPinTap),
          _HeaderIcon(Icons.settings_outlined, onTap: onSettingsTap),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon(this.icon, {this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = MsgrTheme.of(context);
    return IconButton(
      icon: Icon(icon, size: 18, color: t.sidebarText),
      onPressed: onTap,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}
```

**Step 2: Replace the existing header in `simple_chat_content.dart`**

Find where the channel name is shown at the top and replace with:
```dart
ChannelHeader(
  channelName: channel.name,
  topic: channel.topic,
  isPrivate: channel.kind == ChannelKind.private,
  onMembersTap: () => setState(() => _showMembers = !_showMembers),
),
```

**Step 3: Commit**

```bash
git add flutter_frontend/packages/core/lib/ui/shell/channel_header.dart
git add flutter_frontend/packages/core/lib/ui/shell/simple_chat_content.dart
git commit -m "feat(ui): add ChannelHeader with icons and topic display"
```

---

### Task 9: Sidebar Profile Footer with Avatar

**Files:**
- Modify: `flutter_frontend/packages/core/lib/ui/shell/channel_sidebar.dart`

**Step 1: Replace the profile footer**

Replace the bottom `Container` in `ChannelSidebar.build` (the user section) with ProfileAvatar:

```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  decoration: BoxDecoration(
    border: Border(
      top: BorderSide(color: t.contentBorder),
    ),
  ),
  child: Row(
    children: [
      ProfileAvatar(
        profileId: /* current profile id */,
        displayName: userDisplayName ?? '',
        email: userEmail,
        size: MsgrDimensions.sidebarProfileAvatarSize,
        showOnlineIndicator: true,
        isOnline: true,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          userDisplayName ?? userEmail ?? '',
          style: TextStyle(
            color: t.sidebarTextBright,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (onLogout != null)
        IconButton(
          icon: Icon(Icons.logout, color: t.sidebarText, size: 16),
          tooltip: 'Logg ut',
          onPressed: onLogout,
        ),
    ],
  ),
),
```

**Step 2: Wire DmListItem with ProfileAvatar (20px)**

In `dm_list_item.dart`, replace the presence dot with a small `ProfileAvatar` with online indicator.

**Step 3: Commit**

```bash
git add flutter_frontend/packages/core/lib/ui/shell/channel_sidebar.dart
git add flutter_frontend/packages/core/lib/ui/shell/dm_list_item.dart
git commit -m "feat(ui): sidebar profile footer + DM avatars"
```

---

### Task 10: Backend — Avatar URL Field + Upload Endpoint

**Files:**
- Create: `backend/apps/msgr/priv/repo/migrations/TIMESTAMP_add_avatar_url_to_profiles.exs`
- Modify: `backend/apps/msgr/lib/msgr/accounts/profile.ex`
- Modify: `backend/apps/msgr_web/lib/msgr_web/router.ex`
- Create: `backend/apps/msgr_web/lib/msgr_web/controllers/profile_controller.ex` (or modify existing)

**Step 1: Generate migration**

```bash
cd backend && mix ecto.gen.migration add_avatar_url_to_profiles
```

Migration content:
```elixir
def change do
  alter table(:profiles) do
    add :avatar_url, :text
  end
end
```

**Step 2: Add `avatar_url` to Profile schema**

In `profile.ex`, add to schema:
```elixir
field :avatar_url, :string
```

Add to changeset cast list:
```elixir
|> cast(attrs, [:name, :slug, :mode, :theme, :notification_policy, :security_policy, :account_id, :avatar_url])
```

**Step 3: Add avatar upload endpoint**

Add to router:
```elixir
put "/teams/:slug/profile/avatar", ProfileController, :upload_avatar
```

Controller action:
- Creates presigned upload URL for `avatars/{profile_id}.jpg`
- On completion, updates `profile.avatar_url` with public URL
- Returns `%{avatar_url: url}`

**Step 4: Run migration and test**

```bash
mix ecto.migrate
```

**Step 5: Commit**

```bash
git add backend/apps/msgr/priv/repo/migrations/
git add backend/apps/msgr/lib/msgr/accounts/profile.ex
git add backend/apps/msgr_web/
git commit -m "feat(backend): add avatar_url to profiles with upload endpoint"
```

---

### Task 11: Backend — Include avatar_url in API Responses

**Files:**
- Modify: Profile JSON serialization in channel/message API responses

**Step 1: Ensure profile payloads include `avatar_url`**

Find where profile data is serialized in message broadcasts and channel member lists. Add `avatar_url` field:
```elixir
%{
  id: profile.id,
  name: profile.name,
  mode: profile.mode,
  avatar_url: profile.avatar_url
}
```

**Step 2: Deploy and verify**

```bash
git add backend/
git commit -m "feat(backend): include avatar_url in profile API responses"
```

---

### Task 12: Basic Threads — Thread Reply Indicator

**Files:**
- Modify: `flutter_frontend/packages/core/lib/ui/shell/simple_chat_content.dart`

**Step 1: Add thread reply count to SlackMessage model**

In `models.dart`, add to `SlackMessage`:
```dart
final int replyCount;
final List<String> replyAvatarUrls; // up to 3
final DateTime? lastReplyAt;
```

**Step 2: Add _ThreadIndicator widget below messages**

After `_ReactionBar` in `_MessageRow`, add:
```dart
if (msg.replyCount > 0)
  _ThreadIndicator(
    replyCount: msg.replyCount,
    lastReplyAt: msg.lastReplyAt,
    avatarUrls: msg.replyAvatarUrls,
    onTap: () => widget.onOpenThread(msg),
  ),
```

Widget shows: `[overlapping avatars] N replies  Last reply HH:MM`

**Step 3: Commit**

```bash
git add flutter_frontend/packages/core/
git commit -m "feat(threads): add thread reply indicator on messages"
```

---

### Task 13: Basic Threads — Thread Panel

**Files:**
- Modify: `flutter_frontend/packages/core/lib/ui/shell/thread_panel.dart`

**Step 1: Review existing ThreadPanel implementation**

The file already exists — check what's there and enhance with:
- Original message pinned at top (using flat message row style)
- Thread message list below
- Own composer at bottom
- "Also send to #channel" checkbox
- Close button in header

**Step 2: Wire into SimpleChatContent layout**

In `simple_chat_content.dart`, the thread panel should appear as a right-side panel (400px wide) when `_showThread` is true, with a 1px border-left separator.

**Step 3: Backend — thread messages endpoint**

Add API endpoint to fetch messages for a specific thread:
```
GET /api/teams/:slug/channels/:channel_id/threads/:thread_id/messages
```

**Step 4: Commit**

```bash
git add flutter_frontend/packages/core/lib/ui/shell/thread_panel.dart
git add flutter_frontend/packages/core/lib/ui/shell/simple_chat_content.dart
git add backend/
git commit -m "feat(threads): basic thread panel with message list and composer"
```

---

## Execution Order Summary

| Task | Description | Depends on |
|------|------------|------------|
| 1 | Color tokens | — |
| 2 | Dimensions | — |
| 3 | MsgrTheme InheritedWidget | 1, 2 |
| 4 | Migrate ShellTheme refs | 3 |
| 5 | ProfileAvatar widget | 1 |
| 6 | Wire ProfileAvatar into messages | 5 |
| 7 | Sidebar polish (border, colors) | 4 |
| 8 | Channel header | 4 |
| 9 | Sidebar profile footer + DM avatars | 5, 7 |
| 10 | Backend avatar_url field | — |
| 11 | Backend avatar in API responses | 10 |
| 12 | Thread reply indicator | 6 |
| 13 | Thread panel | 12 |

**Parallelizable:** Tasks 1+2, Tasks 5+10, Tasks 7+8, Tasks 12+13 (backend part).

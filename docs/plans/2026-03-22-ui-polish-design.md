# UI Polish: Flat Message Layout, Profiles & Theme System

**Date:** 2026-03-22
**Status:** Approved

## Overview

Transition from WhatsApp-style bubble messages to a Slack-inspired flat layout with grouped messages, real profile avatars, sidebar polish, a centralized theme system, and basic thread support.

## 1. Flat Message Layout with Grouping

Replace bubble-style messages with flat full-width layout.

### First message in a group
```
[Avatar 36px]  Username    14:32
               Message text flows the full width of the
               content area with no bubble background.
```

### Subsequent messages (within 5 min, same sender)
```
               Next message without avatar or name.
               Just text, indented to the same position.
```

### Interaction
- **Hover:** subtle highlight (`rgba(255,255,255,0.04)`) over entire row. Timestamp appears left (where avatar is) for grouped messages. Action bar top-right: emoji react, thread reply, more menu.
- **Grouping window:** 5 minutes same sender = grouped.
- **Username:** `fontWeight: w600`, muted accent color (not white).
- **Timestamp:** `labelSmall`, gray, inline after username.
- **Body:** `bodyMedium`, white/light.
- **Avatar:** 36px round. See section 2 for resolution.

### Mobile considerations
- Same flat layout, narrower margins.
- Avatar shrinks to 32px.
- Action bar triggered by long-press instead of hover.
- Swipe-right on message to reply in thread.

## 2. Profile Avatars (Gravatar + Upload)

### Data model
- New field `avatar_url` (nullable string) on `profiles` table.
- Migration: `ALTER TABLE profiles ADD COLUMN avatar_url TEXT`.

### Resolution order (client-side)
1. `profile.avatar_url` (MinIO presigned URL) -> show image
2. Gravatar URL from account email (`https://gravatar.com/avatar/{md5(email)}?d=404&s=72`) -> show if 200
3. Letter-circle fallback (color from profileId hash)

### Upload flow
- Reuses existing MinIO presigned upload infrastructure.
- New endpoint: `PUT /api/teams/:slug/profile/avatar`
- Cropper widget in profile settings (square, 256x256 output).
- Stored in bucket: `avatars/{profile_id}.jpg`

### Flutter widget
- `ProfileAvatar` widget: takes `Profile` + `size`.
- Uses `CachedNetworkImage` with Gravatar fallback.
- Online-status dot (small green circle, bottom-right).
- Used everywhere: messages, sidebar DM list, member panel, profile card.

## 3. Sidebar Polish

### Color contrast + border
- Sidebar bg: `#1A1D21` (keep)
- Content area bg: `#222529` (raise from current, visible contrast)
- 1px border between sidebar and content: `#2E3035`
- Team rail: `#0F0F10` (keep, darkest)

### Sidebar items
- Selected channel: `#1164A3` bg (accent blue), white text, 6px border-radius
- Hover: `rgba(255,255,255,0.06)` background
- Unread: bold text + white color
- Channel icon: `#` in muted color with spacing
- DM contacts: show ProfileAvatar (20px) with online-dot

### Channel header (top of content area)
- Height: 52px, fixed
- Left: `# channelname` w600 + short topic in gray
- Right: search, members, pin, settings icons
- Border-bottom: 1px `#2E3035`

### Profile footer (sidebar bottom)
- ProfileAvatar (28px) + name + online-dot
- Mic/headset icons (future voice prep)
- Settings gear

## 4. Theme Architecture

Replace hardcoded `ShellTheme` and scattered `ChatTheme` with centralized system.

### File structure
```
lib/ui/theme/
  msgr_theme.dart          -- main class, InheritedWidget, factory methods
  msgr_color_tokens.dart   -- semantic color tokens
  msgr_dimensions.dart     -- spacing, radii, sizes
```

### MsgrColorTokens (semantic naming)
```dart
class MsgrColorTokens {
  // Sidebar
  final Color sidebarBg;
  final Color sidebarItemActive;
  final Color sidebarItemHover;
  final Color sidebarText;
  final Color sidebarTextBright;

  // Content area
  final Color contentBg;
  final Color contentBorder;

  // Messages
  final Color messageHover;
  final Color messageAuthorName;
  final Color messageText;
  final Color messageTimestamp;

  // Header
  final Color headerBg;
  final Color headerBorder;

  // Accents
  final Color accent;
  final Color unreadBadge;
  final Color onlineDot;
}
```

### Predefined themes
- `MsgrTheme.dark()` -- default dark theme (what we build now)
- `MsgrTheme.light()` -- later
- `MsgrTheme.midnight()` -- AMOLED black, later

### MsgrDimensions
```dart
class MsgrDimensions {
  static const messageAvatarSize = 36.0;
  static const messageGroupSpacing = 2.0;
  static const messageNewGroupSpacing = 16.0;
  static const sidebarWidth = 260.0;
  static const teamRailWidth = 56.0;
  static const headerHeight = 52.0;
  static const itemBorderRadius = 6.0;
  static const avatarRadius = 18.0;
}
```

## 5. Basic Threads

### Message thread indicator
- Below a message with replies: `[3 overlapping avatars] 5 replies  Last reply 14:32`
- Clickable row, opens thread panel.

### Thread panel
- Opens right of content area, ~400px wide.
- Header: "Thread" + close button.
- Original message pinned at top.
- Flat message list below (same layout as main chat).
- Own composer at bottom.
- Checkbox: "Also send to #channel".

### Backend
- `thread_id` field already exists on messages.
- `ThreadViewNotifier` already implemented.
- Need: API endpoint for thread messages, channel broadcast with `thread_id`.

### NOT in scope
- Sidebar "Threads" section
- Per-thread unread counts
- Thread notifications

## Implementation Order

1. **Theme system** (tokens + dimensions) -- foundation for everything
2. **Flat message layout** with grouping -- biggest visual change
3. **ProfileAvatar widget** + Gravatar integration -- makes messages look real
4. **Sidebar polish** (border, colors, selected state, avatars)
5. **Channel header** redesign
6. **Avatar upload** (backend endpoint + cropper UI)
7. **Basic threads** (indicator + panel + composer)

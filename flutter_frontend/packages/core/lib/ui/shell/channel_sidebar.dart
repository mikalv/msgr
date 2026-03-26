import 'package:flutter/material.dart';

import 'package:core/l10n/strings.dart';
import 'package:core/ui/theme/msgr_theme.dart';
import 'package:core/ui/widgets/profile_avatar.dart';

import 'channel_list_item.dart';
import 'dm_list_item.dart';
import 'shell_models.dart';

/// Slack-style channel sidebar (240 px wide) with flat list layout.
///
/// Shows team name header with settings/compose buttons, then flat sections
/// for channels and DMs separated by thin dividers.
class ChannelSidebar extends StatelessWidget {
  const ChannelSidebar({
    super.key,
    required this.teamName,
    required this.channels,
    required this.dmContacts,
    this.selectedChannelId,
    this.selectedDmId,
    this.onChannelSelected,
    this.onDmSelected,
    this.onCreateChannel,
    this.onLeaveChannel,
    this.onCloseDm,
    this.favorites = const {},
    this.onToggleFavorite,
    this.onLogout,
    this.onEditProfile,
    this.onOpenSettings,
    this.userEmail,
    this.userDisplayName,
    this.userProfileId,
    this.onAvatarTap,
    this.onInvitePeople,
  });

  final String teamName;
  final List<ChannelItem> channels;
  final List<DmItem> dmContacts;
  final String? selectedChannelId;
  final String? selectedDmId;
  final ValueChanged<ChannelItem>? onChannelSelected;
  final ValueChanged<DmItem>? onDmSelected;
  final VoidCallback? onCreateChannel;
  final ValueChanged<ChannelItem>? onLeaveChannel;
  final ValueChanged<DmItem>? onCloseDm;
  final Set<String> favorites;
  final ValueChanged<String>? onToggleFavorite;
  final VoidCallback? onLogout;
  final VoidCallback? onEditProfile;
  final VoidCallback? onOpenSettings;
  final String? userEmail;
  final String? userDisplayName;
  final String? userProfileId;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onInvitePeople;

  List<ChannelItem> get _starredChannels {
    return _sortedChannels.where((c) => favorites.contains(c.id)).toList();
  }

  List<DmItem> get _starredDms {
    return _sortedDms.where((d) => favorites.contains(d.id)).toList();
  }

  List<ChannelItem> get _sortedChannels {
    final sorted = List<ChannelItem>.from(channels);
    sorted.sort((a, b) {
      if (a.unreadCount > 0 && b.unreadCount == 0) return -1;
      if (a.unreadCount == 0 && b.unreadCount > 0) return 1;
      final aTime = a.lastActivityAt ?? DateTime(2000);
      final bTime = b.lastActivityAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  List<DmItem> get _sortedDms {
    final sorted = List<DmItem>.from(dmContacts);
    sorted.sort((a, b) {
      if (a.unreadCount > 0 && b.unreadCount == 0) return -1;
      if (a.unreadCount == 0 && b.unreadCount > 0) return 1;
      final aTime = a.lastActivityAt ?? DateTime(2000);
      final bTime = b.lastActivityAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final t = MsgrTheme.of(context);
    return Material(
      color: t.sidebarBg,
      child: SizedBox(
        width: MsgrDimensions.sidebarWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Team name header with settings and compose buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      teamName,
                      style: TextStyle(
                        color: t.sidebarTextBright,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.tune, color: t.sidebarText, size: 18),
                    onPressed: onOpenSettings,
                    tooltip: S.settings,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_square, color: t.sidebarText, size: 18),
                    onPressed: () {},
                    tooltip: S.newMessage,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ),

            _buildDivider(),

            // Scrollable content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  // --- Starred / Favorites section ---
                  if (_starredChannels.isNotEmpty || _starredDms.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.star_rounded,
                      title: S.starred,
                    ),
                    const SizedBox(height: 2),
                    for (final channel in _starredChannels)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChannelListItem(
                          channel: channel,
                          isSelected: channel.id == selectedChannelId,
                          onTap: () => onChannelSelected?.call(channel),
                          onLeave: () => onLeaveChannel?.call(channel),
                          onToggleStar: () => onToggleFavorite?.call(channel.id),
                          isStarred: true,
                        ),
                      ),
                    for (final dm in _starredDms)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: DmListItem(
                          contact: dm,
                          isSelected: dm.id == selectedDmId,
                          onTap: () => onDmSelected?.call(dm),
                          onClose: dm.isSelf ? null : () => onCloseDm?.call(dm),
                          onToggleStar: () => onToggleFavorite?.call(dm.id),
                          isStarred: true,
                        ),
                      ),
                    const SizedBox(height: 4),
                    _buildDivider(),
                    const SizedBox(height: 4),
                  ],

                  // --- Channels section ---
                  _SectionHeader(
                    icon: Icons.grid_view_rounded,
                    title: S.channels,
                  ),
                  const SizedBox(height: 2),
                  for (final channel in _sortedChannels)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChannelListItem(
                        channel: channel,
                        isSelected: channel.id == selectedChannelId,
                        onTap: () => onChannelSelected?.call(channel),
                        onLeave: () => onLeaveChannel?.call(channel),
                        onToggleStar: () => onToggleFavorite?.call(channel.id),
                        isStarred: favorites.contains(channel.id),
                      ),
                    ),
                  // + Legg til kanaler
                  _AddButton(
                    label: S.addChannels,
                    onTap: () => onCreateChannel?.call(),
                  ),

                  const SizedBox(height: 4),
                  _buildDivider(),
                  const SizedBox(height: 4),

                  // --- Direct messages section ---
                  _SectionHeader(
                    icon: Icons.chat_bubble_outline,
                    title: S.directMessages,
                  ),
                  const SizedBox(height: 2),
                  for (final dm in _sortedDms)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: DmListItem(
                        contact: dm,
                        isSelected: dm.id == selectedDmId,
                        onTap: () => onDmSelected?.call(dm),
                        onClose: dm.isSelf ? null : () => onCloseDm?.call(dm),
                        onToggleStar: () => onToggleFavorite?.call(dm.id),
                        isStarred: favorites.contains(dm.id),
                      ),
                    ),
                  // + Inviter folk
                  _AddButton(
                    label: S.invitePeople,
                    onTap: () => onInvitePeople?.call(),
                  ),
                ],
              ),
            ),

            // User section at bottom
            if (onLogout != null || userEmail != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: onAvatarTap,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: ProfileAvatar(
                      profileId: userProfileId ?? '',
                      displayName: userDisplayName ?? '',
                      email: userEmail,
                      size: MsgrDimensions.sidebarProfileAvatarSize,
                      showOnlineIndicator: true,
                      isOnline: true,
                    ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: onEditProfile,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              userDisplayName ?? userEmail ?? '',
                              style: TextStyle(
                                color: t.sidebarTextBright,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (userDisplayName != null && userEmail != null)
                              Text(
                                userEmail!,
                                style: TextStyle(
                                  color: t.sidebarText.withAlpha(150),
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (onLogout != null)
                      IconButton(
                        icon: Icon(Icons.logout, color: t.sidebarText, size: 16),
                        tooltip: S.logout,
                        onPressed: onLogout,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _buildDivider() {
    return Container(
      height: 1,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

/// Non-collapsible section header: icon + bold text.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = MsgrTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: t.sidebarText, size: 16),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: t.sidebarText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle "+ Add" inline link matching item indentation.
class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = MsgrTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      hoverColor: t.sidebarItemHover,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                border: Border.all(
                  color: t.sidebarText.withAlpha(128),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.add, size: 12, color: t.sidebarText),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: t.sidebarText.withAlpha(180),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

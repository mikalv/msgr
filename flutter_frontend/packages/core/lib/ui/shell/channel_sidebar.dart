import 'package:flutter/material.dart';

import 'channel_list_item.dart';
import 'dm_list_item.dart';
import 'shell_models.dart';
import 'shell_theme.dart';

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
    this.onLogout,
    this.onEditProfile,
    this.onOpenSettings,
    this.userEmail,
    this.userDisplayName,
  });

  final String teamName;
  final List<MockChannel> channels;
  final List<MockDmContact> dmContacts;
  final String? selectedChannelId;
  final String? selectedDmId;
  final ValueChanged<MockChannel>? onChannelSelected;
  final ValueChanged<MockDmContact>? onDmSelected;
  final VoidCallback? onCreateChannel;
  final VoidCallback? onLogout;
  final VoidCallback? onEditProfile;
  final VoidCallback? onOpenSettings;
  final String? userEmail;
  final String? userDisplayName;

  List<MockChannel> get _sortedChannels {
    final sorted = List<MockChannel>.from(channels);
    sorted.sort((a, b) {
      if (a.unreadCount > 0 && b.unreadCount == 0) return -1;
      if (a.unreadCount == 0 && b.unreadCount > 0) return 1;
      final aTime = a.lastActivityAt ?? DateTime(2000);
      final bTime = b.lastActivityAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  List<MockDmContact> get _sortedDms {
    final sorted = List<MockDmContact>.from(dmContacts);
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
    return Material(
      color: ShellTheme.sidebarBg,
      child: SizedBox(
        width: ShellTheme.sidebarWidth,
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
                      style: const TextStyle(
                        color: ShellTheme.sidebarTextBright,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune, color: ShellTheme.sidebarText, size: 18),
                    onPressed: onOpenSettings,
                    tooltip: 'Settings',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_square, color: ShellTheme.sidebarText, size: 18),
                    onPressed: () {},
                    tooltip: 'Ny melding',
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
                  // --- Channels section ---
                  _SectionHeader(
                    icon: Icons.grid_view_rounded,
                    title: 'Kanaler',
                  ),
                  const SizedBox(height: 2),
                  for (final channel in _sortedChannels)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChannelListItem(
                        channel: channel,
                        isSelected: channel.id == selectedChannelId,
                        onTap: () => onChannelSelected?.call(channel),
                      ),
                    ),
                  // + Legg til kanaler
                  _AddButton(
                    label: 'Legg til kanaler',
                    onTap: () => onCreateChannel?.call(),
                  ),

                  const SizedBox(height: 4),
                  _buildDivider(),
                  const SizedBox(height: 4),

                  // --- Direct messages section ---
                  _SectionHeader(
                    icon: Icons.chat_bubble_outline,
                    title: 'Direktemeldinger',
                  ),
                  const SizedBox(height: 2),
                  for (final dm in _sortedDms)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: DmListItem(
                        contact: dm,
                        isSelected: dm.id == selectedDmId,
                        onTap: () => onDmSelected?.call(dm),
                      ),
                    ),
                  // + Inviter folk
                  _AddButton(
                    label: 'Inviter folk',
                    onTap: () {},
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
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: ShellTheme.onlineDot,
                        shape: BoxShape.circle,
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
                              style: const TextStyle(
                                color: ShellTheme.sidebarTextBright,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (userDisplayName != null && userEmail != null)
                              Text(
                                userEmail!,
                                style: TextStyle(
                                  color: ShellTheme.sidebarText.withAlpha(150),
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
                        icon: const Icon(Icons.logout, color: ShellTheme.sidebarText, size: 16),
                        tooltip: 'Logg ut',
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: ShellTheme.sidebarText, size: 16),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              color: ShellTheme.sidebarText,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      hoverColor: ShellTheme.sidebarHoverItem,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                border: Border.all(
                  color: ShellTheme.sidebarText.withAlpha(128),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.add, size: 12, color: ShellTheme.sidebarText),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: ShellTheme.sidebarText.withAlpha(180),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

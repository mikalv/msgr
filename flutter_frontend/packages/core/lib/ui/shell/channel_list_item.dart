import 'package:flutter/material.dart';

import 'shell_models.dart';
import 'shell_theme.dart';

/// A single channel row in Slack-style flat list.
///
/// Private channels show a lock icon, public channels show `#`.
/// Unread badge appears as a pill on the right side.
class ChannelListItem extends StatelessWidget {
  const ChannelListItem({
    super.key,
    required this.channel,
    required this.isSelected,
    required this.onTap,
  });

  final MockChannel channel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasUnread = channel.unreadCount > 0;
    final textColor =
        hasUnread ? ShellTheme.sidebarTextBright : ShellTheme.sidebarText;
    final fontWeight = hasUnread ? FontWeight.w600 : FontWeight.w400;
    final isPrivate = channel.kind == ChannelKind.private;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      hoverColor: ShellTheme.sidebarHoverItem,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? ShellTheme.sidebarActiveItem : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            // Channel prefix: lock for private, # for public
            Text(
              isPrivate ? '\u{1F512}' : '#',
              style: TextStyle(
                color: ShellTheme.sidebarText,
                fontSize: isPrivate ? 12 : 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                channel.name,
                style: TextStyle(
                  color: textColor,
                  fontWeight: fontWeight,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasUnread)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: ShellTheme.unreadBadge,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${channel.unreadCount}',
                  style: const TextStyle(
                    color: ShellTheme.sidebarTextBright,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

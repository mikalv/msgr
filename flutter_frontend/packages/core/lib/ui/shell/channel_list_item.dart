import 'package:flutter/material.dart';

import 'shell_models.dart';
import 'shell_theme.dart';

/// A single channel row inside the sidebar.
///
/// Shows an optional emoji icon, a `#name` label, an unread badge when
/// [channel.unreadCount] > 0, and an italic "Draft" hint when
/// [channel.hasDraft] is true.
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
    final fontWeight = hasUnread ? FontWeight.w700 : FontWeight.w400;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? ShellTheme.sidebarActiveItem : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            if (channel.iconEmoji.isNotEmpty) ...[
              Text(channel.iconEmoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                '#${channel.name}',
                style: TextStyle(
                  color: textColor,
                  fontWeight: fontWeight,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (channel.hasDraft && !hasUnread)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  'Draft',
                  style: TextStyle(
                    color: ShellTheme.sidebarText,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ),
            if (hasUnread)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

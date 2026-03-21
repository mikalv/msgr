import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  void _showChannelContextMenu(BuildContext context, Offset globalPosition) async {
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        _channelMenuItem('mute', Icons.notifications_off_outlined, 'Demp kanal'),
        _channelMenuItem('leave', Icons.logout, 'Forlat kanal'),
        const PopupMenuDivider(),
        _channelMenuItem('edit', Icons.edit_outlined, 'Rediger kanal'),
        _channelMenuItem('link', Icons.link, 'Kopier lenke'),
      ],
    );

    if (result == null || !context.mounted) return;

    switch (result) {
      case 'link':
        final link = 'msgr://channel/${channel.id}';
        await Clipboard.setData(ClipboardData(text: link));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kanal-lenke kopiert'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kommer snart'),
            duration: Duration(seconds: 2),
          ),
        );
    }
  }

  static PopupMenuItem<String> _channelMenuItem(
    String value,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem<String>(
      value: value,
      height: 36,
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = channel.unreadCount > 0;
    final textColor =
        hasUnread ? ShellTheme.sidebarTextBright : ShellTheme.sidebarText;
    final fontWeight = hasUnread ? FontWeight.w600 : FontWeight.w400;
    final isPrivate = channel.kind == ChannelKind.private;

    return GestureDetector(
      onSecondaryTapUp: (details) =>
          _showChannelContextMenu(context, details.globalPosition),
      onLongPressStart: (details) =>
          _showChannelContextMenu(context, details.globalPosition),
      child: InkWell(
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
      ),
    );
  }
}

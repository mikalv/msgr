import 'package:flutter/material.dart';

import 'package:core/ui/theme/msgr_theme.dart';
import 'package:core/ui/widgets/profile_avatar.dart';

import 'shell_models.dart';

/// A single DM contact row in flat list with context menu.
class DmListItem extends StatelessWidget {
  const DmListItem({
    super.key,
    required this.contact,
    required this.isSelected,
    required this.onTap,
    this.onClose,
    this.onToggleStar,
    this.isStarred = false,
  });

  final DmItem contact;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onClose;
  final VoidCallback? onToggleStar;
  final bool isStarred;

  void _showContextMenu(BuildContext context, Offset globalPosition) async {
    final items = <PopupMenuEntry<String>>[
      _menuItem('star', isStarred ? Icons.star : Icons.star_outline, isStarred ? 'Unstar' : 'Star'),
      _menuItem('mute', Icons.notifications_off_outlined, 'Mute conversation'),
      _menuItem('mark_read', Icons.done_all, 'Mark as read'),
      if (!contact.isSelf) ...[
        const PopupMenuDivider(),
        _menuItem('close', Icons.close, 'Close conversation'),
      ],
    ];

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx, globalPosition.dy,
        globalPosition.dx + 1, globalPosition.dy + 1,
      ),
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: items,
    );

    if (result == null || !context.mounted) return;

    if (result == 'star') {
      onToggleStar?.call();
      return;
    }
    if (result == 'close') {
      onClose?.call();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon'), duration: Duration(seconds: 2)),
    );
  }

  static PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
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
    final t = MsgrTheme.of(context);
    final hasUnread = contact.unreadCount > 0;
    final textColor =
        hasUnread ? t.sidebarTextBright : t.sidebarText;
    final fontWeight = hasUnread ? FontWeight.w600 : FontWeight.w400;

    return GestureDetector(
      onSecondaryTapUp: (details) =>
          _showContextMenu(context, details.globalPosition),
      onLongPressStart: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      hoverColor: t.sidebarItemHover,
      child: Container(
        height: contact.lastMessageText != null ? 42 : 28,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? t.sidebarItemActive : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            // Mini profile avatar with presence indicator
            ProfileAvatar(
              profileId: contact.id,
              displayName: contact.name,
              size: MsgrDimensions.sidebarAvatarSize,
              showOnlineIndicator: true,
              isOnline: contact.isOnline,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: fontWeight,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (contact.lastMessageText != null && contact.lastMessageText!.isNotEmpty)
                    Text(
                      contact.lastMessageText!,
                      style: TextStyle(
                        color: t.sidebarText.withAlpha(120),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (hasUnread)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: t.unreadBadge,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${contact.unreadCount}',
                  style: TextStyle(
                    color: t.sidebarTextBright,
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

import 'package:flutter/material.dart';

import 'shell_models.dart';
import 'shell_theme.dart';

/// A single DM contact row inside the sidebar.
///
/// Renders a small [CircleAvatar] with a green online dot overlay, the
/// contact name, and an unread badge when applicable.
class DmListItem extends StatelessWidget {
  const DmListItem({
    super.key,
    required this.contact,
    required this.isSelected,
    required this.onTap,
  });

  final MockDmContact contact;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasUnread = contact.unreadCount > 0;
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
            // Avatar with online dot
            Stack(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: ShellTheme.sidebarHoverItem,
                  child: Text(
                    contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: ShellTheme.sidebarTextBright,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (contact.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: ShellTheme.onlineDot,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ShellTheme.sidebarBg,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                contact.name,
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
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ShellTheme.unreadBadge,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${contact.unreadCount}',
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

import 'package:flutter/material.dart';

import 'shell_models.dart';
import 'shell_theme.dart';

/// A single DM contact row in Slack-style flat list.
///
/// Shows an inline presence dot (green = online, gray = offline) followed
/// by the contact name, and an unread badge pill on the right.
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
    final fontWeight = hasUnread ? FontWeight.w600 : FontWeight.w400;

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
            // Inline presence dot
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: contact.isOnline
                    ? ShellTheme.onlineDot
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: contact.isOnline
                      ? ShellTheme.onlineDot
                      : ShellTheme.sidebarText.withAlpha(128),
                  width: 1.5,
                ),
              ),
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
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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

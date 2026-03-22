import 'package:flutter/material.dart';

import 'package:core/ui/theme/msgr_theme.dart';
import 'package:core/ui/widgets/profile_avatar.dart';

import 'shell_models.dart';

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
    final t = MsgrTheme.of(context);
    final hasUnread = contact.unreadCount > 0;
    final textColor =
        hasUnread ? t.sidebarTextBright : t.sidebarText;
    final fontWeight = hasUnread ? FontWeight.w600 : FontWeight.w400;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      hoverColor: t.sidebarItemHover,
      child: Container(
        height: 28,
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
    );
  }
}

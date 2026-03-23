import 'package:flutter/material.dart';
import 'package:core/ui/theme/msgr_theme.dart';

class ChannelHeader extends StatelessWidget {
  const ChannelHeader({
    super.key,
    required this.channelName,
    this.topic,
    this.isPrivate = false,
    this.onSearchTap,
    this.onMembersTap,
    this.onPinTap,
    this.onSettingsTap,
  });

  final String channelName;
  final String? topic;
  final bool isPrivate;
  final VoidCallback? onSearchTap;
  final VoidCallback? onMembersTap;
  final VoidCallback? onPinTap;
  final VoidCallback? onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final t = MsgrTheme.of(context);

    return Container(
      height: MsgrDimensions.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: t.headerBg,
        border: Border(
          bottom: BorderSide(color: t.headerBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${isPrivate ? "\u{1F512} " : "# "}$channelName',
            style: TextStyle(
              color: t.sidebarTextBright,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (topic != null && topic!.isNotEmpty) ...[
            const SizedBox(width: 12),
            Container(width: 1, height: 20, color: t.contentBorder),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                topic!,
                style: TextStyle(color: t.messageTimestamp, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            const Spacer(),
          _HeaderIcon(Icons.search, onTap: onSearchTap),
          _HeaderIcon(Icons.people_outline, onTap: onMembersTap),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon(this.icon, {this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = MsgrTheme.of(context);
    return IconButton(
      icon: Icon(icon, size: 18, color: t.sidebarText),
      onPressed: onTap,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:core/ui/theme/msgr_theme.dart';

class ChannelHeader extends StatelessWidget {
  const ChannelHeader({
    super.key,
    required this.channelName,
    this.topic,
    this.isPrivate = false,
    this.pinnedCount = 0,
    this.onSearchTap,
    this.onMembersTap,
    this.onPinTap,
    this.onSettingsTap,
    this.onVoiceCall,
    this.onVideoCall,
    this.isDm = false,
  });

  final String channelName;
  final String? topic;
  final bool isPrivate;
  final int pinnedCount;
  final VoidCallback? onSearchTap;
  final VoidCallback? onMembersTap;
  final VoidCallback? onPinTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onVoiceCall;
  final VoidCallback? onVideoCall;
  final bool isDm;

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
          if (isDm) ...[
            _HeaderIcon(Icons.phone_outlined, onTap: onVoiceCall),
            _HeaderIcon(Icons.videocam_outlined, onTap: onVideoCall),
          ],
          _HeaderIcon(Icons.search, onTap: onSearchTap),
          if (pinnedCount > 0)
            _PinHeaderIcon(count: pinnedCount, onTap: onPinTap)
          else
            _HeaderIcon(Icons.push_pin_outlined, onTap: onPinTap),
          _HeaderIcon(Icons.people_outline, onTap: onMembersTap),
          _HeaderIcon(Icons.settings_outlined, onTap: onSettingsTap),
        ],
      ),
    );
  }
}

class _PinHeaderIcon extends StatelessWidget {
  const _PinHeaderIcon({required this.count, this.onTap});
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = MsgrTheme.of(context);
    return IconButton(
      icon: Badge(
        label: Text('$count', style: const TextStyle(fontSize: 9)),
        backgroundColor: t.accent,
        child: Icon(Icons.push_pin, size: 18, color: t.accent),
      ),
      onPressed: onTap,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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

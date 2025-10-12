import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'presence_badge.dart';
import 'theme/chat_profile_theme.dart';

class ChatChannelSummary {
  const ChatChannelSummary({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.profileId,
    required this.lastActivity,
    this.unreadCount = 0,
    this.isMuted = false,
    this.isOnline = false,
    this.avatar,
  });

  final String id;
  final String title;
  final String subtitle;
  final String profileId;
  final DateTime lastActivity;
  final int unreadCount;
  final bool isMuted;
  final bool isOnline;
  final ImageProvider<Object>? avatar;
}

class ChatChannelList extends StatelessWidget {
  const ChatChannelList({
    super.key,
    required this.channels,
    this.selectedId,
    this.onChannelTap,
    this.onLongPress,
  });

  final List<ChatChannelSummary> channels;
  final String? selectedId;
  final ValueChanged<ChatChannelSummary>? onChannelTap;
  final ValueChanged<ChatChannelSummary>? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (channels.isEmpty) {
      return _EmptyChannelState(
        onCreateTap: onChannelTap == null
            ? null
            : () => onChannelTap!(
                  ChatChannelSummary(
                    id: 'new',
                    title: 'Ny kanal',
                    subtitle: 'Sett i gang en samtale',
                    profileId: 'new',
                    lastActivity: DateTime.now(),
                  ),
                ),
      );
    }

    return ListView.separated(
      itemCount: channels.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final channel = channels[index];
        return _ChannelTile(
          channel: channel,
          isSelected: channel.id == selectedId,
          onTap: onChannelTap,
          onLongPress: onLongPress,
        );
      },
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.isSelected,
    this.onTap,
    this.onLongPress,
  });

  final ChatChannelSummary channel;
  final bool isSelected;
  final ValueChanged<ChatChannelSummary>? onTap;
  final ValueChanged<ChatChannelSummary>? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileTheme = ChatProfileTheme.of(context, channel.profileId);

    final formatted = DateFormat.Hm().format(channel.lastActivity);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null ? () => onTap!(channel) : null,
        onLongPress: onLongPress != null ? () => onLongPress!(channel) : null,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? profileTheme.accentColor.withOpacity(0.12)
                : theme.colorScheme.surfaceVariant.withOpacity(0.36),
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? Border.all(color: profileTheme.accentColor.withOpacity(0.4))
                : null,
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: channel.avatar,
                    backgroundColor: profileTheme.accentColor.withOpacity(0.16),
                    child: channel.avatar == null
                        ? Text(
                            channel.title.isEmpty
                                ? '?'
                                : channel.title.characters.first,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: profileTheme.accentColor,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: PresenceBadge(
                      isOnline: channel.isOnline,
                      color: profileTheme.presenceColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            channel.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          formatted,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      channel.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (channel.unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(left: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: profileTheme.accentColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    channel.unreadCount.toString(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: profileTheme.textStyle.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (channel.isMuted)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.volume_off_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyChannelState extends StatelessWidget {
  const _EmptyChannelState({this.onCreateTap});

  final VoidCallback? onCreateTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined,
              size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            'Ingen kanaler ennå',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Opprett en kanal eller inviter kolleger for å komme i gang.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (onCreateTap != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add_comment_rounded),
              label: const Text('Opprett første kanal'),
            ),
          ],
        ],
      ),
    );
  }
}

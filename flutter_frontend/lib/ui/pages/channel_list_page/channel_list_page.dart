import 'package:flutter/material.dart';
import 'package:messngr/ui/chat_kit/chat_kit.dart';

class ChannelListPage extends StatelessWidget {
  const ChannelListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final channels = _demoChannels();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kanaler'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ChatProfileTheme(
          themes: {
            for (final channel in channels)
              channel.profileId: ChatProfileThemeData.resolve(
                channel.profileId,
                theme: theme,
              ),
          },
          fallback: ChatProfileThemeData.resolve('fallback', theme: theme),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 720;
              return isWide
                  ? Row(
                      children: [
                        Expanded(
                          child: ChatChannelList(
                            channels: channels,
                            selectedId: channels.first.id,
                            onChannelTap: (_) {},
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: ChatThreadViewer(
                            messages: _demoMessages(),
                            onReaction: (_, __) {},
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      children: [
                        ChatChannelList(
                          channels: channels,
                          selectedId: channels.first.id,
                          onChannelTap: (_) {},
                        ),
                        const SizedBox(height: 24),
                        ChatThreadViewer(
                          messages: _demoMessages(),
                          onReaction: (_, __) {},
                        ),
                      ],
                    );
            },
          ),
        ),
      ),
    );
  }

  List<ChatChannelSummary> _demoChannels() {
    final now = DateTime.now();
    return [
      ChatChannelSummary(
        id: 'design',
        title: '#designsystem',
        subtitle: 'Sofie: La oss iterere på headeren',
        profileId: 'design',
        lastActivity: now,
        unreadCount: 3,
        isOnline: true,
      ),
      ChatChannelSummary(
        id: 'product',
        title: '#produkt',
        subtitle: 'Jonas: Backlog refinert',
        profileId: 'product',
        lastActivity: now.subtract(const Duration(minutes: 12)),
        isMuted: true,
      ),
      ChatChannelSummary(
        id: 'random',
        title: '#fredag',
        subtitle: 'Mia: Fredagsquiz kl 16! 🎉',
        profileId: 'random',
        lastActivity: now.subtract(const Duration(minutes: 20)),
      ),
    ];
  }

  List<ChatThreadMessage> _demoMessages() {
    final now = DateTime.now();
    return [
      ChatThreadMessage(
        id: '1',
        profileId: 'design',
        author: 'Sofie',
        body: 'Jeg skisserte en ny variant av presensbadgen.',
        timestamp: now.subtract(const Duration(minutes: 2)),
        isOwn: false,
        reactions: const {'👍': 2},
        isOnline: true,
      ),
      ChatThreadMessage(
        id: '2',
        profileId: 'fallback',
        author: 'Deg',
        body: 'Ser nydelig ut! Jeg polerer UI-kortene også.',
        timestamp: now.subtract(const Duration(minutes: 1)),
        isOwn: true,
        reactions: const {'🔥': 3, '❤️': 1},
        isOnline: true,
      ),
    ];
  }
}

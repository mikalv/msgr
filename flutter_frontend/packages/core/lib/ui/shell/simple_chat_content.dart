import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/providers/auth_state_provider.dart';
import 'package:core/providers/channel_list_provider.dart';
import 'package:core/providers/messages_provider.dart';
import 'package:core/providers/models.dart';

/// Simple chat content area for the AppShell.
///
/// Displays messages for the currently selected channel and a composer
/// to send new messages. Polls for new messages every 3 seconds.
class SimpleChatContent extends ConsumerStatefulWidget {
  const SimpleChatContent({super.key});

  @override
  ConsumerState<SimpleChatContent> createState() => _SimpleChatContentState();
}

class _SimpleChatContentState extends ConsumerState<SimpleChatContent> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _refreshMessages());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _refreshMessages() {
    final channel = ref.read(selectedChannelProvider);
    if (channel == null) return;
    ref.read(channelMessagesProvider.notifier).refresh(channel.id);
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final channel = ref.read(selectedChannelProvider);
    if (channel == null) return;

    ref.read(channelMessagesProvider.notifier).sendMessage(channel.id, text);
    _textController.clear();

    // Scroll to bottom after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedChannel = ref.watch(selectedChannelProvider);
    final messagesState = ref.watch(channelMessagesProvider);
    final auth = ref.watch(simpleAuthProvider);

    if (selectedChannel == null) {
      return const _NoChannelSelected();
    }

    return Material(
      color: const Color(0xFF1E1E1E),
      child: Column(
      children: [
        // Channel header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: Row(
            children: [
              Text(
                '# ${selectedChannel.name}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (selectedChannel.topic != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedChannel.topic!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const Spacer(),
              // Logout button
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
                tooltip: 'Logg ut',
                onPressed: () {
                  ref.read(simpleAuthProvider.notifier).logout();
                },
              ),
            ],
          ),
        ),

        // Messages list
        Expanded(
          child: messagesState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : messagesState.error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Feil ved lasting av meldinger',
                            style: TextStyle(color: Colors.red.shade300),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            messagesState.error.toString(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              ref
                                  .read(channelMessagesProvider.notifier)
                                  .loadMessages(selectedChannel.id);
                            },
                            child: const Text('Prøv igjen'),
                          ),
                        ],
                      ),
                    )
                  : messagesState.messages.isEmpty
                      ? Center(
                          child: Text(
                            'Ingen meldinger ennå',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.5)),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: messagesState.messages.length,
                          itemBuilder: (context, index) {
                            final msg = messagesState.messages[index];
                            final isOwn =
                                msg.senderProfileId == auth.profileId;
                            return _MessageBubble(
                              message: msg,
                              isOwn: isOwn,
                            );
                          },
                        ),
        ),

        // Composer
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Skriv en melding...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send, color: Color(0xFF02ac88)),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isOwn});

  final SlackMessage message;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar placeholder
          CircleAvatar(
            radius: 16,
            backgroundColor:
                isOwn ? const Color(0xFF02ac88) : Colors.blueGrey.shade600,
            child: Text(
              message.senderName.isNotEmpty
                  ? message.senderName[0].toUpperCase()
                  : '?',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      message.senderName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(message.insertedAt),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                    if (message.status == MessageStatus.sending) ...[
                      const SizedBox(width: 6),
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                    ],
                    if (message.status == MessageStatus.failed) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.error_outline,
                          size: 14, color: Colors.redAccent),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  message.content,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _NoChannelSelected extends StatelessWidget {
  const _NoChannelSelected();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Velg en kanal for å starte',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

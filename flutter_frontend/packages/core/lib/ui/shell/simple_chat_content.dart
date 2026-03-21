import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/providers/auth_state_provider.dart';
import 'package:core/providers/channel_list_provider.dart';
import 'package:core/providers/messages_provider.dart';
import 'package:core/providers/models.dart';
import 'package:core/providers/realtime_provider.dart';
import 'package:core/providers/typing_provider.dart';
import 'package:core/ui/shell/member_panel.dart';

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
  Timer? _fallbackPollTimer;
  Timer? _typingDebounce;
  bool _showMembers = false;

  @override
  void initState() {
    super.initState();
    // Fallback polling is started/stopped based on WS connection state
    // in the build method via _syncFallbackPolling.
  }

  @override
  void dispose() {
    _fallbackPollTimer?.cancel();
    _typingDebounce?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Start or stop fallback polling based on WebSocket connection state.
  void _syncFallbackPolling(bool isRealtimeConnected) {
    if (!isRealtimeConnected) {
      // WS is down -- fall back to polling
      _fallbackPollTimer ??=
          Timer.periodic(const Duration(seconds: 5), (_) => _refreshMessages());
    } else {
      // WS is up -- stop polling
      _fallbackPollTimer?.cancel();
      _fallbackPollTimer = null;
    }
  }

  void _refreshMessages() {
    final channel = ref.read(selectedChannelProvider);
    if (channel == null) return;
    ref.read(channelMessagesProvider.notifier).refresh(channel.id);
  }

  void _onTextChanged(String text) {
    final channel = ref.read(selectedChannelProvider);
    if (channel == null) return;
    final realtime = ref.read(realtimeProvider.notifier);

    if (text.isNotEmpty) {
      _typingDebounce?.cancel();
      realtime.sendTypingStart(channel.id);
      _typingDebounce = Timer(const Duration(seconds: 3), () {
        realtime.sendTypingStop(channel.id);
      });
    } else {
      _typingDebounce?.cancel();
      realtime.sendTypingStop(channel.id);
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final channel = ref.read(selectedChannelProvider);
    if (channel == null) return;

    ref.read(channelMessagesProvider.notifier).sendMessage(channel.id, text);
    _textController.clear();
    _typingDebounce?.cancel();
    ref.read(realtimeProvider.notifier).sendTypingStop(channel.id);

    // With reverse: true, new messages appear at position 0 (bottom) automatically.
    // Just scroll to 0 to ensure we're at the latest.
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedChannel = ref.watch(selectedChannelProvider);
    final messagesState = ref.watch(channelMessagesProvider);
    final auth = ref.watch(simpleAuthProvider);

    // Activate the realtime provider (auto-connects on login)
    final realtimeState = ref.watch(realtimeProvider);
    _syncFallbackPolling(realtimeState.isConnected);

    // Typing indicators for the current channel
    final typing = selectedChannel != null
        ? ref.watch(channelTypingProvider(selectedChannel.id))
        : <String>[];

    if (selectedChannel == null) {
      return const _NoChannelSelected();
    }

    return Material(
      color: const Color(0xFF1E1E1E),
      child: Row(
      children: [
        // Main chat area
        Expanded(
          child: Column(
          children: [
        // Reconnecting banner
        if (!realtimeState.isConnected && auth.isLoggedIn)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: Colors.orange.shade800,
            child: const Text(
              'Kobler til igjen...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
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
              // Members panel toggle
              IconButton(
                icon: Icon(
                  _showMembers ? Icons.people : Icons.people_outline,
                  color: _showMembers ? const Color(0xFF02ac88) : Colors.white54,
                  size: 20,
                ),
                tooltip: 'Medlemmer',
                onPressed: () {
                  setState(() => _showMembers = !_showMembers);
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
                          reverse: true,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: messagesState.messages.length,
                          itemBuilder: (context, index) {
                            // reverse: true flips the list — index 0 = newest
                            final msg = messagesState.messages[
                                messagesState.messages.length - 1 - index];
                            final isOwn =
                                msg.senderProfileId == auth.profileId;
                            return _MessageBubble(
                              message: msg,
                              isOwn: isOwn,
                            );
                          },
                        ),
        ),

        // Typing indicator
        if (typing.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Text(
              '${typing.join(', ')} skriver...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
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
                  autofocus: true,
                  onChanged: _onTextChanged,
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
        ),

        // Member panel (conditionally shown)
        if (_showMembers)
          MemberPanel(
            onClose: () => setState(() => _showMembers = false),
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
                    color: message.status == MessageStatus.sending
                        ? Colors.white.withOpacity(0.4)
                        : message.status == MessageStatus.failed
                            ? Colors.redAccent.withOpacity(0.6)
                            : Colors.white.withOpacity(0.85),
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

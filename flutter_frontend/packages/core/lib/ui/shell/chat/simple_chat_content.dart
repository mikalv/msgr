import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libmsgr/api.dart' show MsgrApiClient;
import 'package:url_launcher/url_launcher.dart';

import 'package:core/providers/auth_state_provider.dart';
import 'package:core/providers/channel_list_provider.dart';
import 'package:core/providers/command_provider.dart';
import 'package:core/providers/mention_provider.dart';
import 'package:core/providers/messages_provider.dart';
import 'package:core/providers/models.dart';
import 'package:core/providers/msgr_client_provider.dart';
import 'package:core/providers/realtime_provider.dart';
import 'package:core/providers/team_list_provider.dart';
import 'package:core/providers/thread_provider.dart';
import 'package:core/providers/typing_provider.dart';
import 'package:core/features/chat/widgets/chat_composer.dart';
import 'package:core/ui/shell/channel_header.dart';
import 'package:core/ui/shell/member_panel.dart';
import 'package:core/ui/shell/profile_card.dart';
import 'package:core/ui/shell/thread_panel.dart';
import 'package:core/ui/widgets/profile_avatar.dart';
import 'package:core/ui/theme/msgr_theme.dart';

part 'chat_helpers.dart';
part 'message_list.dart';
part 'message_row.dart';
part 'message_content.dart';
part 'media_attachments.dart';
part 'reaction_bar.dart';
part 'thread_indicator.dart';

// ---------------------------------------------------------------------------
// Main widget
// ---------------------------------------------------------------------------

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
  final _composerController = ChatComposerController();
  Timer? _fallbackPollTimer;
  Timer? _typingDebounce;
  bool _showMembers = false;
  bool _showThread = false;
  bool _showNewMessagesBanner = false;
  int _previousMessageCount = 0;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _fallbackPollTimer?.cancel();
    _typingDebounce?.cancel();
    _textController.dispose();
    _composerController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // If user scrolled back to bottom, hide the banner.
    if (_scrollController.hasClients && _scrollController.offset <= 20) {
      if (_showNewMessagesBanner) {
        setState(() => _showNewMessagesBanner = false);
      }
    }
  }

  /// Start or stop fallback polling based on WebSocket connection state.
  /// Only polls when WebSocket is disconnected AND user is authenticated.
  void _syncFallbackPolling(bool isRealtimeConnected) {
    if (!isRealtimeConnected) {
      final auth = ref.read(simpleAuthProvider);
      if (auth.accessToken != null && auth.accessToken!.isNotEmpty) {
        _fallbackPollTimer ??=
            Timer.periodic(const Duration(seconds: 15), (_) => _refreshMessages());
      } else {
        // Not authenticated — don't poll
        _fallbackPollTimer?.cancel();
        _fallbackPollTimer = null;
      }
    } else {
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

  void _onComposerSubmit(ChatComposerResult result) async {
    final hasText = result.text.trim().isNotEmpty;
    final hasAttachments = result.attachments.isNotEmpty;
    if (!hasText && !hasAttachments) return;

    final channel = ref.read(selectedChannelProvider);
    if (channel == null) return;
    final team = ref.read(selectedTeamProvider);
    if (team == null) return;

    // Check if this is a slash command submission
    if (result.hasCommand || result.text.trim().startsWith('/')) {
      await _executeSlashCommand(team, channel, result);
      return;
    }

    // Validate attachment sizes (50 MB limit).
    for (final att in result.attachments) {
      if (att.size > MsgrApiClient.maxFileSize) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${att.name} er for stor (maks 50 MB)'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
        return;
      }
    }

    // Build structured mention data from the composer result.
    final text = result.text.trim();
    final mentionDataList = <MentionData>[];
    if (result.hasMentions) {
      for (final mention in result.mentions) {
        final pattern = '@${mention.handle}';
        var searchFrom = 0;
        while (true) {
          final idx = text.indexOf(pattern, searchFrom);
          if (idx < 0) break;
          mentionDataList.add(MentionData(
            profileId: mention.id,
            displayName: mention.handle,
            offset: idx,
            length: pattern.length,
          ));
          searchFrom = idx + pattern.length;
        }
      }
      mentionDataList.sort((a, b) => a.offset.compareTo(b.offset));
    }

    setState(() => _isSending = true);
    _composerController.clear();

    try {
      // Upload attachments via libmsgr and collect object keys.
      final mediaRefs = <String>[];
      if (hasAttachments) {
        final client = ref.read(msgrApiProvider);
        for (final att in result.attachments) {
          final bytes = att.bytes ?? Uint8List(0);
          if (bytes.isEmpty) continue;
          final objectKey = await client.uploadFileToChannel(
            team.slug,
            channel.id,
            filename: att.name,
            bytes: bytes,
            contentType: att.mimeType ?? 'application/octet-stream',
          );
          mediaRefs.add(objectKey);
        }
      }

      ref.read(channelMessagesProvider.notifier).sendMessage(
        channel.id,
        text.isNotEmpty ? text : (mediaRefs.isNotEmpty ? '[vedlegg]' : ''),
        mediaRefs: mediaRefs.isNotEmpty ? mediaRefs : null,
        mentions: mentionDataList.isNotEmpty ? mentionDataList : null,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opplasting feilet: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
    _scrollToBottom();
  }

  /// Execute a slash command via the server API.
  Future<void> _executeSlashCommand(
    SlackTeam team,
    SlackChannel channel,
    ChatComposerResult result,
  ) async {
    final text = result.text.trim();

    // Parse command name and args from the text
    String commandName;
    String? args;
    if (result.hasCommand) {
      // Command was selected from the palette
      commandName = result.command!.name.replaceFirst('/', '');
      // Everything after the command name in text is the args
      final cmdPrefix = '/${commandName}';
      if (text.startsWith(cmdPrefix)) {
        args = text.substring(cmdPrefix.length).trim();
      } else {
        args = text;
      }
    } else {
      // User typed /command manually
      final parts = text.split(RegExp(r'\s+'));
      commandName = parts.first.replaceFirst('/', '');
      args = parts.length > 1 ? parts.sublist(1).join(' ') : null;
    }

    if (commandName.isEmpty) return;

    setState(() => _isSending = true);
    _composerController.clear();

    try {
      final client = ref.read(msgrApiProvider);
      await client.executeCommand(
        team.slug,
        channel.id,
        commandName,
        args?.isNotEmpty == true ? args : null,
      );
      // The server posts a system message to the channel via realtime,
      // so we just need to refresh messages to pick it up.
      _refreshMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kommando feilet: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
    _scrollToBottom();
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

    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    }
    if (_showNewMessagesBanner) {
      setState(() => _showNewMessagesBanner = false);
    }
  }

  /// Check if new messages arrived while user is scrolled up.
  void _checkNewMessages(int currentCount) {
    if (_previousMessageCount > 0 &&
        currentCount > _previousMessageCount &&
        _scrollController.hasClients &&
        _scrollController.offset > 100) {
      if (!_showNewMessagesBanner) {
        setState(() => _showNewMessagesBanner = true);
      }
    }
    _previousMessageCount = currentCount;
  }

  @override
  Widget build(BuildContext context) {
    final selectedChannel = ref.watch(selectedChannelProvider);
    final messagesState = ref.watch(channelMessagesProvider);
    final auth = ref.watch(simpleAuthProvider);
    final mentionCandidates = ref.watch(mentionCandidatesProvider);
    final slashCommands = ref.watch(slashCommandsProvider);

    final realtimeState = ref.watch(realtimeProvider);
    _syncFallbackPolling(realtimeState.isConnected);

    final typing = selectedChannel != null
        ? ref.watch(channelTypingProvider(selectedChannel.id))
        : <String>[];

    if (selectedChannel == null) {
      return const _NoChannelSelected();
    }

    final messages = messagesState.messages;
    _checkNewMessages(messages.length);

    return Material(
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
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
                ChannelHeader(
                  channelName: selectedChannel.name,
                  topic: selectedChannel.topic,
                  isPrivate: selectedChannel.visibility == ChannelVisibility.private,
                  onMembersTap: () => setState(() => _showMembers = !_showMembers),
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
                                    style:
                                        TextStyle(color: Colors.red.shade300),
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
                                          .read(
                                              channelMessagesProvider.notifier)
                                          .loadMessages(selectedChannel.id);
                                    },
                                    child: const Text('Pr\u00f8v igjen'),
                                  ),
                                ],
                              ),
                            )
                          : messages.isEmpty
                              ? Center(
                                  child: Text(
                                    'Ingen meldinger enn\u00e5',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.5)),
                                  ),
                                )
                              : Stack(
                                  children: [
                                    _MessageList(
                                      messages: messages,
                                      scrollController: _scrollController,
                                      currentProfileId: auth.profileId,
                                      onOpenThread: _openThread,
                                    ),
                                    // "New messages" banner
                                    if (_showNewMessagesBanner)
                                      Positioned(
                                        bottom: 8,
                                        left: 0,
                                        right: 0,
                                        child: Center(
                                          child: _NewMessagesBanner(
                                            onTap: _scrollToBottom,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                ),

                // Typing indicator
                if (typing.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: Text(
                      '${typing.join(', ')} skriver...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                // Rich composer
                ChatComposer(
                  controller: _composerController,
                  isSending: _isSending,
                  onSubmit: _onComposerSubmit,
                  availableCommands: slashCommands.when(
                    data: (commands) => commands,
                    loading: () => SlashCommand.defaults,
                    error: (_, __) => SlashCommand.defaults,
                  ),
                  availableMentions: mentionCandidates,
                ),
              ],
            ),
          ),

          // Thread panel (conditionally shown)
          if (_showThread)
            ThreadPanel(
              onClose: () => setState(() => _showThread = false),
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

  void _openThread(SlackMessage message) {
    ref.read(threadMessagesProvider.notifier).openThread(message);
    setState(() => _showThread = true);
  }
}

// ---------------------------------------------------------------------------
// "Nye meldinger" banner
// ---------------------------------------------------------------------------

class _NewMessagesBanner extends StatelessWidget {
  const _NewMessagesBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF02ac88),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nye meldinger',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_downward, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// No channel selected placeholder
// ---------------------------------------------------------------------------

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
            'Velg en kanal for \u00e5 starte',
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

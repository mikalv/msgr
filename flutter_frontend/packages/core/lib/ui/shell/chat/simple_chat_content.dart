import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libmsgr/api.dart' show MsgrApiClient;
import 'package:url_launcher/url_launcher.dart';

import 'package:core/l10n/strings.dart';
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
import 'package:core/providers/unread_provider.dart';

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
  SlackMessage? _editingMessage;
  String? _draftBeforeEdit;
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
            content: Text('${S.uploadFailed}: $e'),
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
            content: Text('${S.commandFailed}: $e'),
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

    // Mark channel as read when viewing it (deferred to avoid modifying provider during build)
    if (selectedChannel != null && messagesState.messages.isNotEmpty) {
      final chId = selectedChannel.id;
      // Find the last server-confirmed message ID (not local-*)
      String? lastServerId;
      for (var i = messagesState.messages.length - 1; i >= 0; i--) {
        final id = messagesState.messages[i].id;
        if (!id.startsWith('local-')) {
          lastServerId = id;
          break;
        }
      }
      if (lastServerId != null) {
        Future.microtask(() {
          ref.read(unreadCountsProvider.notifier).markRead(chId, lastMessageId: lastServerId);
        });
      }
    }

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
                    child: Text(
                      S.reconnecting,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),

                // Channel header
                ChannelHeader(
                  channelName: selectedChannel.name,
                  topic: selectedChannel.topic,
                  isPrivate: selectedChannel.visibility == ChannelVisibility.private,
                  onSearchTap: () => _showSearchDialog(context, selectedChannel),
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
                                    S.loadingError,
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
                                    child: Text(S.tryAgain),
                                  ),
                                ],
                              ),
                            )
                          : messages.isEmpty
                              ? Center(
                                  child: Text(
                                    S.noMessagesYet,
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
                                      onEdit: _startEdit,
                                      onDelete: _deleteMessage,
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
                      S.typing(typing),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                // Edit mode banner
                if (_editingMessage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: const Color(0xFF2E3035),
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 14, color: Color(0xFF4FC3F7)),
                        const SizedBox(width: 8),
                        Text(
                          S.editingMessage,
                          style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 13),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _cancelEdit,
                          child: const Icon(Icons.close, size: 16, color: Color(0xFFD1D2D3)),
                        ),
                      ],
                    ),
                  ),

                // Rich composer
                ChatComposer(
                  controller: _composerController,
                  isSending: _isSending,
                  onSubmit: _editingMessage != null ? _onEditSubmit : _onComposerSubmit,
                  onArrowUp: _onArrowUp,
                  onEscape: _editingMessage != null ? _cancelEdit : null,
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

  void _showSearchDialog(BuildContext context, SlackChannel channel) {
    final team = ref.read(selectedTeamProvider);
    if (team == null) return;

    showDialog(
      context: context,
      builder: (ctx) => _SearchDialog(teamSlug: team.slug, channelId: channel.id),
    );
  }

  void _deleteMessage(SlackMessage message) async {
    final team = ref.read(selectedTeamProvider);
    if (team == null) return;

    // Optimistic remove
    ref.read(channelMessagesProvider.notifier).removeMessage(message.id);

    try {
      final client = ref.read(msgrApiProvider);
      await client.deleteMessage(team.slug, message.channelId, message.id);
    } catch (e) {
      // Re-add on failure
      ref.read(channelMessagesProvider.notifier).mergeIncoming(message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${S.couldNotDelete}: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  void _openThread(SlackMessage message) {
    ref.read(threadMessagesProvider.notifier).openThread(message);
    setState(() => _showThread = true);
  }

  void _onArrowUp() {
    // Only trigger when composer is empty
    if (_composerController.value.text.isNotEmpty) return;

    final auth = ref.read(simpleAuthProvider);
    final messages = ref.read(channelMessagesProvider).messages;

    // Find last own message
    SlackMessage? lastOwn;
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].senderProfileId == auth.profileId && !messages[i].isSystem) {
        lastOwn = messages[i];
        break;
      }
    }
    if (lastOwn == null) return;

    _startEdit(lastOwn);
  }

  void _startEdit(SlackMessage message) {
    setState(() {
      _draftBeforeEdit = _composerController.value.text;
      _editingMessage = message;
    });
    _composerController.setText(message.content);
  }

  void _cancelEdit() {
    setState(() {
      _editingMessage = null;
    });
    _composerController.setText(_draftBeforeEdit ?? '');
    _draftBeforeEdit = null;
  }

  void _onEditSubmit(ChatComposerResult result) async {
    final message = _editingMessage;
    if (message == null) return;

    final newText = result.text.trim();
    if (newText.isEmpty || newText == message.content) {
      _cancelEdit();
      return;
    }

    setState(() {
      _editingMessage = null;
      _isSending = true;
    });

    try {
      final team = ref.read(selectedTeamProvider);
      if (team == null) return;

      final client = ref.read(msgrApiProvider);
      await client.editMessage(team.slug, message.channelId, message.id, newText);

      // Optimistic update
      ref.read(channelMessagesProvider.notifier).updateMessage(
        message.id,
        content: newText,
        editedAt: DateTime.now(),
      );

      _composerController.clear();
      _draftBeforeEdit = null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${S.couldNotEdit}: $e'), backgroundColor: Colors.red.shade700),
        );
      }
      // Restore edit mode
      setState(() => _editingMessage = message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              S.newMessages,
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
            S.selectChannelToStart,
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

// ---------------------------------------------------------------------------
// Search dialog
// ---------------------------------------------------------------------------

class _SearchDialog extends ConsumerStatefulWidget {
  const _SearchDialog({required this.teamSlug, required this.channelId});
  final String teamSlug;
  final String channelId;

  @override
  ConsumerState<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends ConsumerState<_SearchDialog> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final client = ref.read(msgrApiProvider);
      final results = await client.searchMessages(
        widget.teamSlug,
        query,
        channelId: widget.channelId,
      );
      if (mounted) setState(() { _results = results; _loading = false; });
    } catch (e) {
      debugPrint('[Search] Error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF222529),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 500,
        height: 450,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onQueryChanged,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: S.searchMessages,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFD1D2D3)),
                  filled: true,
                  fillColor: const Color(0xFF1A1D21),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else
              Expanded(
                child: _results.isEmpty
                    ? Center(
                        child: Text(
                          _controller.text.length < 2
                              ? S.minTwoChars
                              : S.noResults,
                          style: TextStyle(color: Colors.white.withOpacity(0.4)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final r = _results[index];
                          return ListTile(
                            title: Text(
                              r['sender_name'] ?? 'Ukjent',
                              style: const TextStyle(
                                color: Color(0xFF4FC3F7),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              r['content'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFFD1D2D3), fontSize: 13),
                            ),
                            trailing: Text(
                              r['inserted_at']?.toString().substring(0, 10) ?? '',
                              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                            ),
                            onTap: () => Navigator.of(context).pop(),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

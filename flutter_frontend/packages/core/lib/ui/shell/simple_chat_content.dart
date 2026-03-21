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
import 'package:core/providers/mention_provider.dart';
import 'package:core/providers/messages_provider.dart';
import 'package:core/providers/models.dart';
import 'package:core/providers/msgr_client_provider.dart';
import 'package:core/providers/realtime_provider.dart';
import 'package:core/providers/team_list_provider.dart';
import 'package:core/providers/thread_provider.dart';
import 'package:core/providers/typing_provider.dart';
import 'package:core/features/chat/widgets/chat_composer.dart';
import 'package:core/ui/shell/member_panel.dart';
import 'package:core/ui/shell/thread_panel.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _groupingThreshold = Duration(minutes: 5);
const _avatarRadius = 18.0; // 36px diameter
const _avatarSlotWidth = 36.0 + 10.0; // avatar + gap

/// Deterministic color palette for sender names.
const _nameColors = <Color>[
  Color(0xFF4FC3F7), // light blue
  Color(0xFF81C784), // green
  Color(0xFFFFB74D), // orange
  Color(0xFFBA68C8), // purple
  Color(0xFFE57373), // red
  Color(0xFF4DD0E1), // cyan
  Color(0xFFFFF176), // yellow
  Color(0xFFA1887F), // brown
  Color(0xFF90A4AE), // blue grey
  Color(0xFFF06292), // pink
];

Color _colorForName(String name) {
  var hash = 0;
  for (var i = 0; i < name.length; i++) {
    hash = name.codeUnitAt(i) + ((hash << 5) - hash);
  }
  return _nameColors[hash.abs() % _nameColors.length];
}

// ---------------------------------------------------------------------------
// URL regex for auto-linking plain text
// ---------------------------------------------------------------------------

final _urlRegex = RegExp(
  r'https?://[^\s<>\)\]]+',
  caseSensitive: false,
);

// ---------------------------------------------------------------------------
// Timestamp / date helpers (Norwegian)
// ---------------------------------------------------------------------------

const _monthsNb = [
  'jan', 'feb', 'mar', 'apr', 'mai', 'jun',
  'jul', 'aug', 'sep', 'okt', 'nov', 'des',
];

String _formatTimestamp(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final msgDay = DateTime(dt.year, dt.month, dt.day);
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  final time = '$hh:$mm';

  if (msgDay == today) return time;
  if (msgDay == today.subtract(const Duration(days: 1))) return 'I g\u00e5r $time';
  return '${dt.day}. ${_monthsNb[dt.month - 1]} $time';
}

String _formatDateSeparator(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final msgDay = DateTime(dt.year, dt.month, dt.day);

  if (msgDay == today) return 'I dag';
  if (msgDay == today.subtract(const Duration(days: 1))) return 'I g\u00e5r';
  return '${dt.day}. ${_monthsNb[dt.month - 1]} ${dt.year}';
}

bool _isDifferentDay(DateTime a, DateTime b) {
  return a.year != b.year || a.month != b.month || a.day != b.day;
}

// ---------------------------------------------------------------------------
// Grouping helper
// ---------------------------------------------------------------------------

/// Whether [msg] starts a new visual group compared to [prev].
bool _startsNewGroup(SlackMessage msg, SlackMessage? prev) {
  if (prev == null) return true;
  if (msg.senderProfileId != prev.senderProfileId) return true;
  if (msg.insertedAt.difference(prev.insertedAt).abs() > _groupingThreshold) {
    return true;
  }
  return false;
}

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
  void _syncFallbackPolling(bool isRealtimeConnected) {
    if (!isRealtimeConnected) {
      _fallbackPollTimer ??=
          Timer.periodic(const Duration(seconds: 5), (_) => _refreshMessages());
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    border: Border(
                      bottom:
                          BorderSide(color: Colors.white.withOpacity(0.1)),
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
                      IconButton(
                        icon: Icon(
                          _showMembers ? Icons.people : Icons.people_outline,
                          color: _showMembers
                              ? const Color(0xFF02ac88)
                              : Colors.white54,
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
                  availableMentions: mentionCandidates.when(
                    data: (mentions) => mentions,
                    loading: () => ComposerMention.defaults,
                    error: (_, __) => ComposerMention.defaults,
                  ),
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
// Message list with grouping + date separators
// ---------------------------------------------------------------------------

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.scrollController,
    required this.currentProfileId,
    required this.onOpenThread,
  });

  final List<SlackMessage> messages;
  final ScrollController scrollController;
  final String? currentProfileId;
  final void Function(SlackMessage) onOpenThread;

  @override
  Widget build(BuildContext context) {
    // Build a list of render items (date separators + message rows).
    // Messages are in chronological order; ListView is reverse:true so
    // index 0 = newest. We iterate from oldest to newest to compute groups,
    // then reverse the list of widgets.
    final items = <Widget>[];

    for (var i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final prev = i > 0 ? messages[i - 1] : null;

      // Date separator
      if (prev == null || _isDifferentDay(msg.insertedAt, prev.insertedAt)) {
        items.add(_DateSeparator(date: msg.insertedAt));
      }

      final isGroupStart = _startsNewGroup(msg, prev);
      final isOwn = msg.senderProfileId == currentProfileId;

      items.add(_MessageRow(
        message: msg,
        isGroupStart: isGroupStart,
        isOwn: isOwn,
        onOpenThread: onOpenThread,
      ));
    }

    // Reverse so that index 0 = newest for the reversed ListView.
    final reversed = items.reversed.toList();

    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: reversed.length,
      itemBuilder: (context, index) => reversed[index],
    );
  }
}

// ---------------------------------------------------------------------------
// Date separator
// ---------------------------------------------------------------------------

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.white.withOpacity(0.12), height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatDateSeparator(date),
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.white.withOpacity(0.12), height: 1)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message row (with grouping, hover, avatar, markdown)
// ---------------------------------------------------------------------------

class _MessageRow extends ConsumerStatefulWidget {
  const _MessageRow({
    required this.message,
    required this.isGroupStart,
    required this.isOwn,
    required this.onOpenThread,
  });

  final SlackMessage message;
  final bool isGroupStart;
  final bool isOwn;
  final void Function(SlackMessage) onOpenThread;

  @override
  ConsumerState<_MessageRow> createState() => _MessageRowState();
}

class _MessageRowState extends ConsumerState<_MessageRow> {
  bool _hovered = false;

  void _showContextMenu(BuildContext context, Offset globalPosition) async {
    final msg = widget.message;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final position = RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      globalPosition.dx + 1,
      globalPosition.dy + 1,
    );

    final result = await showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        _buildContextMenuItem('copy', Icons.copy, 'Kopier tekst'),
        _buildContextMenuItem('thread', Icons.reply, 'Svar i tr\u00e5d'),
        _buildContextMenuItem('reaction', Icons.emoji_emotions_outlined, 'Legg til reaksjon'),
        _buildContextMenuItem('pin', Icons.push_pin_outlined, 'Fest melding'),
        const PopupMenuDivider(),
        if (widget.isOwn) ...[
          _buildContextMenuItem('edit', Icons.edit_outlined, 'Rediger'),
          _buildContextMenuItem('delete', Icons.delete_outline, 'Slett', isDestructive: true),
          const PopupMenuDivider(),
        ],
        _buildContextMenuItem('link', Icons.link, 'Kopier lenke'),
      ],
    );

    if (result == null || !context.mounted) return;

    switch (result) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: msg.content));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tekst kopiert'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        break;
      case 'thread':
        widget.onOpenThread(msg);
        break;
      case 'link':
        final link = 'msgr://channel/${msg.channelId}/message/${msg.id}';
        await Clipboard.setData(ClipboardData(text: link));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lenke kopiert'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kommer snart'),
            duration: Duration(seconds: 2),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onSecondaryTapUp: (details) =>
            _showContextMenu(context, details.globalPosition),
        onLongPressStart: (details) =>
            _showContextMenu(context, details.globalPosition),
        child: Container(
        color: _hovered ? Colors.white.withOpacity(0.03) : Colors.transparent,
        padding: EdgeInsets.only(
          top: widget.isGroupStart ? 8 : 1,
          bottom: 1,
          left: 4,
          right: 4,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar or empty slot
            SizedBox(
              width: _avatarSlotWidth,
              child: widget.isGroupStart
                  ? Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: CircleAvatar(
                        radius: _avatarRadius,
                        backgroundColor: _colorForName(msg.senderName)
                            .withOpacity(0.25),
                        child: Text(
                          msg.senderName.isNotEmpty
                              ? msg.senderName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: _colorForName(msg.senderName),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  : // Show compact timestamp on hover for continuation rows
                  _hovered
                      ? Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _formatTimestamp(msg.insertedAt),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 10,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
            ),

            // Content column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + timestamp row (only for group start)
                  if (widget.isGroupStart)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          Text(
                            msg.senderName,
                            style: TextStyle(
                              color: _colorForName(msg.senderName),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTimestamp(msg.insertedAt),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 11,
                            ),
                          ),
                          if (msg.status == MessageStatus.sending) ...[
                            const SizedBox(width: 6),
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5),
                            ),
                          ],
                          if (msg.status == MessageStatus.failed) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.error_outline,
                                size: 14, color: Colors.redAccent),
                          ],
                        ],
                      ),
                    ),

                  // Message content (markdown or plain text with links + mentions)
                  _MessageContent(
                    content: msg.content,
                    status: msg.status,
                    mentions: msg.mentions,
                  ),

                  // Media attachments (images and files)
                  if (msg.mediaRefs.isNotEmpty)
                    _MediaAttachments(mediaRefs: msg.mediaRefs),

                  // Reaction bar — always reserve space to prevent layout jumps.
                  // Hidden when empty + not hovered via opacity.
                  AnimatedOpacity(
                    opacity: msg.reactions.isNotEmpty || _hovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: _ReactionBar(
                      reactions: msg.reactions,
                      onToggle: (emoji) {
                        ref
                            .read(channelMessagesProvider.notifier)
                            .toggleReaction(msg.id, emoji);
                      },
                    ),
                  ),

                  // Thread indicator
                  if (msg.hasThreadReplies)
                    _ThreadIndicator(
                      replyCount: msg.threadReplyCount,
                      onTap: () => widget.onOpenThread(msg),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared context menu item builder
// ---------------------------------------------------------------------------

PopupMenuEntry<String> _buildContextMenuItem(
  String value,
  IconData icon,
  String label, {
  bool isDestructive = false,
}) {
  return PopupMenuItem<String>(
    value: value,
    height: 36,
    child: Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDestructive ? Colors.redAccent : Colors.white70,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: isDestructive ? Colors.redAccent : Colors.white,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Reaction bar + pills
// ---------------------------------------------------------------------------

/// Row of reaction pills below a message, with a '+' button to add new ones.
class _ReactionBar extends StatelessWidget {
  const _ReactionBar({
    super.key,
    required this.reactions,
    required this.onToggle,
  });

  final List<MessageReaction> reactions;
  final ValueChanged<String> onToggle;

  static const _quickEmoji = [
    '\u{1F44D}', '\u{2764}\u{FE0F}', '\u{1F602}', '\u{1F389}',
    '\u{2705}', '\u{1F440}', '\u{1F525}', '\u{1F4AF}',
    '\u{1F680}', '\u{1F64F}', '\u{1F914}', '\u{1F60D}',
    '\u{1F44F}', '\u{1F929}', '\u{1F4A1}', '\u{2615}\u{FE0F}',
    '\u{1F31F}', '\u{1F3B5}', '\u{1F4AA}', '\u{1F60E}',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final reaction in reactions)
            _ReactionPill(
              emoji: reaction.emoji,
              count: reaction.count,
              isActive: reaction.includesMe,
              onTap: () => onToggle(reaction.emoji),
            ),
          _AddReactionButton(
            onSelected: onToggle,
            quickEmoji: _quickEmoji,
          ),
        ],
      ),
    );
  }
}

/// A compact reaction pill: [emoji count] with highlighted border if user reacted.
class _ReactionPill extends StatelessWidget {
  const _ReactionPill({
    super.key,
    required this.emoji,
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF02ac88).withOpacity(0.25)
                : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF02ac88).withOpacity(0.6)
                  : Colors.white.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 3),
              Text(
                '$count',
                style: TextStyle(
                  color: isActive ? const Color(0xFF02ac88) : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small '+' button that opens a simple emoji grid popup.
class _AddReactionButton extends StatelessWidget {
  const _AddReactionButton({
    super.key,
    required this.onSelected,
    required this.quickEmoji,
  });

  final ValueChanged<String> onSelected;
  final List<String> quickEmoji;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showPicker(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.add_reaction_outlined,
            size: 14,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final position = box.localToGlobal(Offset.zero, ancestor: overlay);

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy - 180,
        position.dx + 280,
        position.dy,
      ),
      constraints: const BoxConstraints(maxWidth: 280, maxHeight: 200),
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 260,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final emoji in quickEmoji)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(emoji),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child:
                            Text(emoji, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );

    if (selected != null) {
      onSelected(selected);
    }
  }
}

// ---------------------------------------------------------------------------
// Thread indicator
// ---------------------------------------------------------------------------

class _ThreadIndicator extends StatefulWidget {
  const _ThreadIndicator({
    required this.replyCount,
    required this.onTap,
  });

  final int replyCount;
  final VoidCallback onTap;

  @override
  State<_ThreadIndicator> createState() => _ThreadIndicatorState();
}

class _ThreadIndicatorState extends State<_ThreadIndicator> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.forum_outlined,
                size: 14,
                color: _hovered
                    ? const Color(0xFF4FC3F7)
                    : const Color(0xFF4FC3F7).withOpacity(0.7),
              ),
              const SizedBox(width: 4),
              Text(
                '${widget.replyCount} svar',
                style: TextStyle(
                  color: _hovered
                      ? const Color(0xFF4FC3F7)
                      : const Color(0xFF4FC3F7).withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration:
                      _hovered ? TextDecoration.underline : TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Media attachments: inline images + file download cards
// ---------------------------------------------------------------------------

/// Known image extensions for client-side type inference from object keys.
const _imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.svg'};

bool _isImageRef(String ref) {
  final lower = ref.toLowerCase();
  return _imageExtensions.any((ext) => lower.endsWith(ext));
}

String _filenameFromRef(String ref) {
  final parts = ref.split('/');
  return parts.isNotEmpty ? parts.last : ref;
}

/// Renders media attachments (images inline, other files as download cards).
class _MediaAttachments extends ConsumerWidget {
  const _MediaAttachments({required this.mediaRefs});

  final List<String> mediaRefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (mediaRefs.isEmpty) return const SizedBox.shrink();

    final images = mediaRefs.where(_isImageRef).toList();
    final files = mediaRefs.where((r) => !_isImageRef(r)).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Inline image thumbnails
          if (images.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in images)
                  _ImageThumbnail(objectKey: key),
              ],
            ),
          // File download cards
          if (files.isNotEmpty)
            ...files.map((key) => _FileCard(objectKey: key)),
        ],
      ),
    );
  }
}

/// Inline image thumbnail that can be clicked to expand.
class _ImageThumbnail extends ConsumerStatefulWidget {
  const _ImageThumbnail({required this.objectKey});

  final String objectKey;

  @override
  ConsumerState<_ImageThumbnail> createState() => _ImageThumbnailState();
}

class _ImageThumbnailState extends ConsumerState<_ImageThumbnail> {
  String? _url;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    try {
      final team = ref.read(selectedTeamProvider);
      if (team == null) return;
      final client = ref.read(msgrApiProvider);
      final url = await client.getDownloadUrl(team.slug, widget.objectKey);
      if (mounted) setState(() { _url = url; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = true; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (_error || _url == null || _url!.isEmpty) {
      return Container(
        width: 200,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            _filenameFromRef(widget.objectKey),
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showFullImage(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 300),
          child: Image.network(
            _url!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 200,
                height: 150,
                color: Colors.white.withOpacity(0.05),
                child: const Center(
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              );
            },
            errorBuilder: (context, error, stack) {
              return Container(
                width: 200,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Kunne ikke laste bilde',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context) {
    if (_url == null) return;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _ImageOverlay(url: _url!, filename: _filenameFromRef(widget.objectKey)),
    );
  }
}

/// Full-size image overlay dialog.
class _ImageOverlay extends StatelessWidget {
  const _ImageOverlay({required this.url, required this.filename});

  final String url;
  final String filename;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) {
                  return Center(
                    child: Text(
                      'Kunne ikke laste bilde',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  filename,
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 24),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Download card for non-image files.
class _FileCard extends ConsumerStatefulWidget {
  const _FileCard({required this.objectKey});

  final String objectKey;

  @override
  ConsumerState<_FileCard> createState() => _FileCardState();
}

class _FileCardState extends ConsumerState<_FileCard> {
  bool _downloading = false;

  IconData _iconForFile(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lower.endsWith('.zip') || lower.endsWith('.tar') || lower.endsWith('.gz')) return Icons.folder_zip;
    if (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.avi')) return Icons.videocam;
    if (lower.endsWith('.mp3') || lower.endsWith('.wav') || lower.endsWith('.ogg')) return Icons.audiotrack;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return Icons.description;
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) return Icons.table_chart;
    return Icons.insert_drive_file;
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final team = ref.read(selectedTeamProvider);
      if (team == null) return;
      final client = ref.read(msgrApiProvider);
      final url = await client.getDownloadUrl(team.slug, widget.objectKey);
      if (url.isNotEmpty) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nedlasting feilet: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filename = _filenameFromRef(widget.objectKey);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        onTap: _downloading ? null : _download,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _iconForFile(filename),
                color: const Color(0xFF4FC3F7),
                size: 28,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      filename,
                      style: const TextStyle(
                        color: Color(0xFF4FC3F7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Klikk for aa laste ned',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_downloading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.download,
                  color: Colors.white.withOpacity(0.5),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message content: markdown rendering + auto-link fallback
// ---------------------------------------------------------------------------

class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.content,
    required this.status,
    this.mentions = const [],
  });

  final String content;
  final MessageStatus status;
  final List<MentionData> mentions;

  /// Returns true if the text likely contains markdown formatting.
  bool get _hasMarkdown {
    return content.contains('**') ||
        content.contains('__') ||
        content.contains('*') ||
        content.contains('~~') ||
        content.contains('```') ||
        content.contains('`') ||
        content.contains('- ') ||
        content.contains('* ') ||
        content.contains('[') ||
        content.contains('# ');
  }

  Color _textColor() {
    if (status == MessageStatus.sending) return Colors.white.withOpacity(0.4);
    if (status == MessageStatus.failed) {
      return Colors.redAccent.withOpacity(0.6);
    }
    return Colors.white.withOpacity(0.9);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasMarkdown && mentions.isEmpty) {
      return MarkdownBody(
        data: content,
        selectable: true,
        onTapLink: (text, href, title) {
          if (href != null) {
            launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
          }
        },
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(color: _textColor(), fontSize: 14, height: 1.4),
          strong: TextStyle(
              color: _textColor(),
              fontSize: 14,
              fontWeight: FontWeight.w700),
          em: TextStyle(
              color: _textColor(),
              fontSize: 14,
              fontStyle: FontStyle.italic),
          del: TextStyle(
              color: _textColor(),
              fontSize: 14,
              decoration: TextDecoration.lineThrough),
          code: TextStyle(
            color: const Color(0xFFE8E8E8),
            backgroundColor: Colors.white.withOpacity(0.08),
            fontSize: 13,
            fontFamily: 'monospace',
          ),
          codeblockDecoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          codeblockPadding: const EdgeInsets.all(10),
          codeblockAlign: WrapAlignment.start,
          blockquoteDecoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                  color: Colors.white.withOpacity(0.3), width: 3),
            ),
          ),
          blockquotePadding:
              const EdgeInsets.only(left: 12, top: 4, bottom: 4),
          a: const TextStyle(
            color: Color(0xFF4FC3F7),
            decoration: TextDecoration.underline,
            fontSize: 14,
          ),
          listBullet: TextStyle(color: _textColor(), fontSize: 14),
          h1: TextStyle(
              color: _textColor(),
              fontSize: 20,
              fontWeight: FontWeight.w700),
          h2: TextStyle(
              color: _textColor(),
              fontSize: 18,
              fontWeight: FontWeight.w700),
          h3: TextStyle(
              color: _textColor(),
              fontSize: 16,
              fontWeight: FontWeight.w700),
        ),
      );
    }

    // Plain text with auto-linked URLs + mention highlighting
    return _LinkedText(
      content: content,
      color: _textColor(),
      mentions: mentions,
    );
  }
}

// ---------------------------------------------------------------------------
// Auto-linked plain text
// ---------------------------------------------------------------------------

/// Regex to detect @mentions in plain text (fallback when no structured data).
final _mentionRegex = RegExp(r'@[\w.]+');

class _LinkedText extends StatelessWidget {
  const _LinkedText({
    required this.content,
    required this.color,
    this.mentions = const [],
  });

  final String content;
  final Color color;
  final List<MentionData> mentions;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(color: color, fontSize: 14, height: 1.4);

    // Build a set of highlighted ranges from structured mention data.
    // If no structured mentions exist, fall back to regex detection.
    final highlightRanges = <_HighlightRange>[];

    if (mentions.isNotEmpty) {
      for (final m in mentions) {
        if (m.offset >= 0 && m.offset + m.length <= content.length) {
          highlightRanges.add(_HighlightRange(
            start: m.offset,
            end: m.offset + m.length,
            name: m.displayName,
          ));
        }
      }
    } else {
      // Regex fallback: detect @word patterns in text.
      for (final match in _mentionRegex.allMatches(content)) {
        highlightRanges.add(_HighlightRange(
          start: match.start,
          end: match.end,
          name: content.substring(match.start + 1, match.end),
        ));
      }
    }

    // Merge URL matches and mention highlights into a single sorted list
    // of "special" ranges, then build spans.
    final urlMatches = _urlRegex.allMatches(content).toList();

    // Combine all special ranges (urls + mentions), sorted by start.
    final allRanges = <_TextRange>[];
    for (final m in urlMatches) {
      allRanges.add(_TextRange(start: m.start, end: m.end, kind: _RangeKind.url));
    }
    for (final h in highlightRanges) {
      allRanges.add(_TextRange(start: h.start, end: h.end, kind: _RangeKind.mention, name: h.name));
    }
    allRanges.sort((a, b) => a.start.compareTo(b.start));

    // Remove overlapping ranges (first-come wins).
    final resolved = <_TextRange>[];
    var occupiedUntil = 0;
    for (final r in allRanges) {
      if (r.start >= occupiedUntil) {
        resolved.add(r);
        occupiedUntil = r.end;
      }
    }

    if (resolved.isEmpty) {
      return Text(content, style: baseStyle);
    }

    final spans = <InlineSpan>[];
    var lastEnd = 0;

    for (final range in resolved) {
      if (range.start > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, range.start),
          style: baseStyle,
        ));
      }

      final segment = content.substring(range.start, range.end);

      if (range.kind == _RangeKind.url) {
        spans.add(TextSpan(
          text: segment,
          style: const TextStyle(
            color: Color(0xFF4FC3F7),
            decoration: TextDecoration.underline,
            fontSize: 14,
            height: 1.4,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              launchUrl(Uri.parse(segment), mode: LaunchMode.externalApplication);
            },
        ));
      } else {
        // Mention pill-style highlight.
        final mentionColor = _colorForName(range.name ?? segment);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: mentionColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              segment,
              style: TextStyle(
                color: mentionColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ));
      }

      lastEnd = range.end;
    }

    if (lastEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return SelectableText.rich(TextSpan(children: spans));
  }
}

enum _RangeKind { url, mention }

class _TextRange {
  const _TextRange({
    required this.start,
    required this.end,
    required this.kind,
    this.name,
  });
  final int start;
  final int end;
  final _RangeKind kind;
  final String? name;
}

class _HighlightRange {
  const _HighlightRange({
    required this.start,
    required this.end,
    required this.name,
  });
  final int start;
  final int end;
  final String name;
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

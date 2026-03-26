import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/features/chat/widgets/chat_composer.dart';
import 'package:core/providers/auth_state_provider.dart';
import 'package:core/providers/mention_provider.dart';
import 'package:core/providers/models.dart';
import 'package:core/providers/thread_provider.dart';

/// Side panel that displays a message thread (parent + replies).
///
/// Opens to the right of the main chat area, similar to Slack's thread panel.
/// Width is resizable via a drag handle on the left border.
class ThreadPanel extends ConsumerStatefulWidget {
  const ThreadPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<ThreadPanel> createState() => _ThreadPanelState();
}

class _ThreadPanelState extends ConsumerState<ThreadPanel> {
  late final ChatComposerController _composerController;
  final _scrollController = ScrollController();
  double _panelWidth = 350;
  static const _minWidth = 280.0;
  static const _maxWidth = 600.0;

  @override
  void initState() {
    super.initState();
    _composerController = ChatComposerController();
  }

  @override
  void dispose() {
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSubmit(ChatComposerResult result) {
    final text = result.text.trim();
    if (text.isEmpty) return;
    ref.read(threadMessagesProvider.notifier).reply(text);
    _composerController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final threadState = ref.watch(threadMessagesProvider);
    final auth = ref.watch(simpleAuthProvider);

    return Row(
      children: [
        // Drag handle for resizing
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _panelWidth = (_panelWidth - details.delta.dx)
                    .clamp(_minWidth, _maxWidth);
              });
            },
            child: Container(
              width: 4,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
        ),
        // Panel content
        SizedBox(
          width: _panelWidth,
          child: Material(
            color: const Color(0xFF252525),
            child: Column(
              children: [
                // Header
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
                      const Icon(Icons.forum_outlined,
                          color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Trad',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white54, size: 18),
                        onPressed: () {
                          ref
                              .read(threadMessagesProvider.notifier)
                              .closeThread();
                          widget.onClose();
                        },
                        tooltip: 'Lukk trad',
                        splashRadius: 16,
                      ),
                    ],
                  ),
                ),

                // Thread content
                Expanded(
                  child: threadState.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : threadState.error != null
                          ? Center(
                              child: Text(
                                'Feil ved lasting av trad',
                                style:
                                    TextStyle(color: Colors.red.shade300),
                              ),
                            )
                          : ListView(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(12),
                              children: [
                                // Parent message
                                if (threadState.parentMessage != null)
                                  _ThreadMessageTile(
                                    message: threadState.parentMessage!,
                                    isOwn: threadState
                                            .parentMessage!.senderProfileId ==
                                        auth.profileId,
                                    isParent: true,
                                  ),
                                if (threadState.parentMessage != null)
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            height: 1,
                                            color: Colors.white
                                                .withOpacity(0.1),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: Text(
                                            '${threadState.replies.length} svar',
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withOpacity(0.4),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            height: 1,
                                            color: Colors.white
                                                .withOpacity(0.1),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Replies
                                ...threadState.replies.map(
                                  (reply) => _ThreadMessageTile(
                                    message: reply,
                                    isOwn: reply.senderProfileId ==
                                        auth.profileId,
                                    isParent: false,
                                  ),
                                ),
                              ],
                            ),
                ),

                // Reply composer — reuses ChatComposer for @mention + slash commands
                ChatComposer(
                  controller: _composerController,
                  onSubmit: _onSubmit,
                  isSending: false,
                  availableMentions: ref.watch(mentionCandidatesProvider),
                  availableCommands: const [],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ThreadMessageTile extends StatelessWidget {
  const _ThreadMessageTile({
    required this.message,
    required this.isOwn,
    required this.isParent,
  });

  final MsgrMessage message;
  final bool isOwn;
  final bool isParent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isParent ? 16 : 14,
            backgroundColor:
                isOwn ? const Color(0xFF02ac88) : Colors.blueGrey.shade600,
            child: Text(
              message.senderName.isNotEmpty
                  ? message.senderName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                  color: Colors.white, fontSize: isParent ? 14 : 12),
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
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: isParent ? 13 : 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(message.insertedAt),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 10,
                      ),
                    ),
                    if (message.status == MessageStatus.sending) ...[
                      const SizedBox(width: 4),
                      const SizedBox(
                        width: 8,
                        height: 8,
                        child: CircularProgressIndicator(strokeWidth: 1),
                      ),
                    ],
                    if (message.status == MessageStatus.failed) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.error_outline,
                          size: 12, color: Colors.redAccent),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  message.content,
                  style: TextStyle(
                    color: message.status == MessageStatus.failed
                        ? Colors.redAccent.withOpacity(0.6)
                        : Colors.white.withOpacity(0.85),
                    fontSize: isParent ? 14 : 13,
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

part of 'simple_chat_content.dart';

// ---------------------------------------------------------------------------
// Message row (with grouping, hover, avatar, markdown)
// ---------------------------------------------------------------------------

class _MessageRow extends ConsumerStatefulWidget {
  const _MessageRow({
    required this.message,
    required this.isGroupStart,
    required this.isOwn,
    required this.onOpenThread,
    this.onEdit,
    this.onDelete,
  });

  final SlackMessage message;
  final bool isGroupStart;
  final bool isOwn;
  final void Function(SlackMessage) onOpenThread;
  final void Function(SlackMessage)? onEdit;
  final void Function(SlackMessage)? onDelete;

  @override
  ConsumerState<_MessageRow> createState() => _MessageRowState();
}

class _MessageRowState extends ConsumerState<_MessageRow> {
  bool _hovered = false;

  void _showSenderProfile(BuildContext context) {
    final msg = widget.message;
    final auth = ref.read(simpleAuthProvider);
    final isOwn = auth.profileId == msg.senderProfileId;

    showProfileCard(
      context,
      profile: SlackProfile(
        id: msg.senderProfileId,
        displayName: msg.senderName,
      ),
      isOwnProfile: isOwn,
    );
  }

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
        _buildContextMenuItem('copy', Icons.copy, S.copyText),
        _buildContextMenuItem('thread', Icons.reply, S.replyInThread),
        _buildContextMenuItem('reaction', Icons.emoji_emotions_outlined, S.addReaction),
        _buildContextMenuItem('pin', Icons.push_pin_outlined, S.pinMessage),
        const PopupMenuDivider(),
        if (widget.isOwn) ...[
          _buildContextMenuItem('edit', Icons.edit_outlined, S.edit),
          _buildContextMenuItem('delete', Icons.delete_outline, S.delete, isDestructive: true),
          const PopupMenuDivider(),
        ],
        _buildContextMenuItem('link', Icons.link, S.copyLink),
      ],
    );

    if (result == null || !context.mounted) return;

    switch (result) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: msg.content));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.textCopied),
              duration: Duration(seconds: 2),
            ),
          );
        }
        break;
      case 'thread':
        widget.onOpenThread(msg);
        break;
      case 'edit':
        widget.onEdit?.call(msg);
        break;
      case 'delete':
        widget.onDelete?.call(msg);
        break;
      case 'link':
        final link = 'msgr://channel/${msg.channelId}/message/${msg.id}';
        await Clipboard.setData(ClipboardData(text: link));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.linkCopied),
              duration: Duration(seconds: 2),
            ),
          );
        }
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.comingSoon),
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
              width: MsgrDimensions.messageAvatarSlot,
              child: widget.isGroupStart
                  ? Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: GestureDetector(
                        onTap: () => _showSenderProfile(context),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: ProfileAvatar(
                            profileId: msg.senderProfileId,
                            displayName: msg.senderName,
                            avatarUrl: msg.senderAvatarUrl,
                            email: msg.senderEmail,
                            size: MsgrDimensions.messageAvatarSize,
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
                          GestureDetector(
                            onTap: () => _showSenderProfile(context),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Text(
                                msg.senderName,
                                style: TextStyle(
                                  color: _colorForName(msg.senderName),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
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
                          if (msg.editedAt != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              S.edited,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.25),
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
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

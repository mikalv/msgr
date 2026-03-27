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
    this.onReply,
    this.onTogglePin,
  });

  final MsgrMessage message;
  final bool isGroupStart;
  final bool isOwn;
  final void Function(MsgrMessage) onOpenThread;
  final void Function(MsgrMessage)? onEdit;
  final void Function(MsgrMessage)? onDelete;
  final void Function(MsgrMessage)? onReply;
  final void Function(MsgrMessage)? onTogglePin;

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
      profile: MsgrProfile(
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
        _buildContextMenuItem('reply', Icons.reply_outlined, 'Reply'),
        _buildContextMenuItem('thread', Icons.forum_outlined, S.replyInThread),
        _buildContextMenuItem('reaction', Icons.emoji_emotions_outlined, S.addReaction),
        _buildContextMenuItem('pin', msg.pinned ? Icons.push_pin : Icons.push_pin_outlined, msg.pinned ? 'Unpin' : 'Pin message'),
        const PopupMenuDivider(),
        if (widget.isOwn) ...[
          _buildContextMenuItem('edit', Icons.edit_outlined, S.edit),
          _buildContextMenuItem('delete', Icons.delete_outline, S.delete, isDestructive: true),
          const PopupMenuDivider(),
        ],
        _buildContextMenuItem('remind', Icons.alarm, 'Remind me'),
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
      case 'reply':
        widget.onReply?.call(msg);
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
      case 'pin':
        widget.onTogglePin?.call(msg);
        break;
      case 'remind':
        if (context.mounted) await _showRemindMenu(context, globalPosition, msg);
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

  Future<void> _showRemindMenu(BuildContext context, Offset pos, MsgrMessage msg) async {
    final now = DateTime.now();
    final position = RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1);

    final result = await showMenu<Duration?>(
      context: context,
      position: position,
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        _remindItem(const Duration(minutes: 10), '10 minutes'),
        _remindItem(const Duration(minutes: 20), '20 minutes'),
        _remindItem(const Duration(minutes: 30), '30 minutes'),
        _remindItem(const Duration(hours: 1), '1 hour'),
        _remindItem(Duration(hours: _hoursUntilTomorrow9am(now)), 'Tomorrow 9:00 AM'),
        _remindItem(Duration(hours: _hoursUntilNextMonday9am(now)), 'Next Monday 9:00 AM'),
      ],
    );

    if (result == null || !context.mounted) return;

    final remindAt = now.add(result).toUtc();

    try {
      final team = ref.read(selectedTeamProvider);
      if (team == null) return;
      final client = ref.read(msgrApiProvider);
      await client.createReminder(
        team.slug,
        messageId: msg.id,
        remindAt: remindAt.toIso8601String(),
        channelId: msg.channelId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder set!'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set reminder: $e'), duration: Duration(seconds: 3)),
        );
      }
    }
  }

  PopupMenuItem<Duration> _remindItem(Duration d, String label) {
    return PopupMenuItem<Duration>(
      value: d,
      height: 36,
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 16, color: Colors.white70),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  int _hoursUntilTomorrow9am(DateTime now) {
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 9);
    return tomorrow.difference(now).inHours.clamp(1, 48);
  }

  int _hoursUntilNextMonday9am(DateTime now) {
    var daysUntilMonday = (DateTime.monday - now.weekday) % 7;
    if (daysUntilMonday == 0) daysUntilMonday = 7;
    final nextMonday = DateTime(now.year, now.month, now.day + daysUntilMonday, 9);
    return nextMonday.difference(now).inHours.clamp(1, 168);
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
        child: Stack(
        clipBehavior: Clip.none,
        children: [
        Container(
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
                      child: ProfileHoverCard(
                        profileId: msg.senderProfileId,
                        displayName: msg.senderName,
                        avatarUrl: msg.senderAvatarUrl,
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
                          ProfileHoverCard(
                            profileId: msg.senderProfileId,
                            displayName: msg.senderName,
                            avatarUrl: msg.senderAvatarUrl,
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
                          if (msg.pinned) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.push_pin, size: 12, color: MsgrTheme.of(context).accent.withAlpha(180)),
                          ],
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

                  // Quote block for reply-to messages
                  if (msg.replyTo != null)
                    Builder(builder: (context) {
                      final theme = MsgrTheme.of(context);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border(left: BorderSide(color: theme.accent, width: 3)),
                          color: theme.accent.withAlpha(15),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(6),
                            bottomRight: Radius.circular(6),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.replyTo!.senderName,
                              style: TextStyle(
                                color: theme.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              msg.replyTo!.content,
                              style: TextStyle(
                                color: theme.messageText.withAlpha(150),
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    }),

                  // Rich content types (location, contact) or regular text
                  if (msg.contentType == 'location' && msg.contentData != null)
                    _LocationCard(data: msg.contentData!)
                  else if (msg.contentType == 'contact' && msg.contentData != null)
                    _ContactCard(data: msg.contentData!)
                  else if (msg.content.isNotEmpty)
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

      // Hover toolbar — positioned top-right
      if (_hovered)
        Positioned(
          top: -4,
          right: 8,
          child: _HoverToolbar(
            onReact: () {},
            onThread: () => widget.onOpenThread(msg),
            onReply: () => widget.onReply?.call(msg),
            onPin: () => widget.onTogglePin?.call(msg),
            isPinned: msg.pinned,
            onMore: (pos) => _showContextMenu(context, pos),
          ),
        ),
      ],
      ),
      ),
    );
  }
}

/// Floating toolbar shown on message hover (Slack-style).
class _HoverToolbar extends StatelessWidget {
  const _HoverToolbar({
    required this.onReact,
    required this.onThread,
    required this.onReply,
    required this.onPin,
    required this.isPinned,
    required this.onMore,
  });

  final VoidCallback onReact;
  final VoidCallback onThread;
  final VoidCallback onReply;
  final VoidCallback onPin;
  final bool isPinned;
  final void Function(Offset) onMore;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(6),
      color: const Color(0xFF2A2D30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolbarButton(icon: Icons.emoji_emotions_outlined, tooltip: 'React', onTap: onReact),
            _ToolbarButton(icon: Icons.reply_outlined, tooltip: 'Reply', onTap: onReply),
            _ToolbarButton(icon: Icons.forum_outlined, tooltip: 'Thread', onTap: onThread),
            _ToolbarButton(icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined, tooltip: isPinned ? 'Unpin' : 'Pin', onTap: onPin),
            _ToolbarButton(icon: Icons.more_horiz, tooltip: 'More', onTapWithPosition: onMore),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.icon, required this.tooltip, this.onTap, this.onTapWithPosition});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final void Function(Offset)? onTapWithPosition;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTapDown: onTapWithPosition != null ? (d) => onTapWithPosition!(d.globalPosition) : null,
        onTap: onTapWithPosition == null ? onTap : null,
        hoverColor: Colors.white.withAlpha(15),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: Colors.white60),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rich content cards
// ---------------------------------------------------------------------------

/// Location card with static map thumbnail from OpenStreetMap.
class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final lat = (data['lat'] as num?)?.toDouble() ?? 0;
    final lng = (data['lng'] as num?)?.toDouble() ?? 0;
    final label = data['label']?.toString() ?? '$lat, $lng';
    final zoom = (data['zoom'] as num?)?.toInt() ?? 15;

    // OpenStreetMap static tile URL (no API key needed)
    final tileUrl = 'https://staticmap.openstreetmap.de/staticmap.php'
        '?center=$lat,$lng&zoom=$zoom&size=300x180&markers=$lat,$lng,red-pushpin';

    return GestureDetector(
      onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=$zoom/$lat/$lng')),
      child: Container(
        width: 300,
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withAlpha(20)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              tileUrl,
              width: 300,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 300,
                height: 180,
                color: Colors.white.withAlpha(10),
                child: const Center(child: Icon(Icons.map, color: Colors.white38, size: 40)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.redAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Contact card showing name, phone, email with action buttons.
class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final name = data['name']?.toString() ?? 'Unknown';
    final phone = data['phone']?.toString();
    final email = data['email']?.toString();
    final org = data['organization']?.toString();

    return Container(
      width: 280,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withAlpha(20)),
        color: Colors.white.withAlpha(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blueGrey.withAlpha(60),
                child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    if (org != null)
                      Text(org, style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.contact_page_outlined, size: 18, color: Colors.white38),
            ],
          ),
          if (phone != null || email != null) ...[
            const SizedBox(height: 8),
            Divider(color: Colors.white.withAlpha(15), height: 1),
            const SizedBox(height: 8),
            if (phone != null)
              _contactRow(Icons.phone_outlined, phone, () => launchUrl(Uri.parse('tel:$phone'))),
            if (email != null)
              _contactRow(Icons.email_outlined, email, () => launchUrl(Uri.parse('mailto:$email'))),
          ],
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.white38),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

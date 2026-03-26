part of 'simple_chat_content.dart';

// ---------------------------------------------------------------------------
// Message list with grouping + date separators
// ---------------------------------------------------------------------------

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.scrollController,
    required this.currentProfileId,
    required this.onOpenThread,
    this.onEdit,
    this.onDelete,
    this.onReply,
  });

  final List<MsgrMessage> messages;
  final ScrollController scrollController;
  final String? currentProfileId;
  final void Function(MsgrMessage) onOpenThread;
  final void Function(MsgrMessage)? onEdit;
  final void Function(MsgrMessage)? onDelete;
  final void Function(MsgrMessage)? onReply;

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

      // System messages render with a distinct centered style
      if (msg.isSystem) {
        items.add(_SystemMessageRow(message: msg));
        continue;
      }

      final isGroupStart = _startsNewGroup(msg, prev);
      final isOwn = msg.senderProfileId == currentProfileId;

      items.add(_MessageRow(
        message: msg,
        isGroupStart: isGroupStart,
        isOwn: isOwn,
        onOpenThread: onOpenThread,
        onEdit: isOwn ? onEdit : null,
        onDelete: isOwn ? onDelete : null,
        onReply: onReply,
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
// System message row (centered, muted, no avatar)
// ---------------------------------------------------------------------------

class _SystemMessageRow extends StatelessWidget {
  const _SystemMessageRow({required this.message});
  final MsgrMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            message.content,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }
}

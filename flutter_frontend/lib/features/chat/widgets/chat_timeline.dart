import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:messngr/features/chat/models/chat_message.dart';
import 'package:messngr/features/chat/widgets/chat_bubble.dart';

class ChatTimeline extends StatefulWidget {
  const ChatTimeline({
    super.key,
    required this.messages,
    required this.currentProfileId,
  });

  final List<ChatMessage> messages;
  final String currentProfileId;

  @override
  State<ChatTimeline> createState() => _ChatTimelineState();
}

class _ChatTimelineState extends State<ChatTimeline> {
  final ScrollController _controller = ScrollController();
  int _lastCount = 0;

  @override
  void didUpdateWidget(covariant ChatTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != _lastCount) {
      _lastCount = widget.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_controller.hasClients) return;
        _controller.animateTo(
          _controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
      return const _EmptyState();
    }

    return ListView.builder(
      controller: _controller,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: widget.messages.length,
      itemBuilder: (context, index) {
        final message = widget.messages[index];
        final previous = index > 0 ? widget.messages[index - 1] : null;
        final showDayDivider = _shouldShowDivider(message, previous);
        final isMine = message.profileId == widget.currentProfileId;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDayDivider)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _DayDivider(date: message.insertedAt ?? DateTime.now()),
              ),
            ChatBubble(message: message, isMine: isMine),
          ],
        );
      },
    );
  }

  bool _shouldShowDivider(ChatMessage current, ChatMessage? previous) {
    final currentDate = (current.insertedAt ?? current.sentAt)?.toLocal();
    final previousDate = (previous?.insertedAt ?? previous?.sentAt)?.toLocal();
    if (currentDate == null) {
      return false;
    }
    if (previousDate == null) {
      return true;
    }
    return currentDate.year != previousDate.year ||
        currentDate.month != previousDate.month ||
        currentDate.day != previousDate.day;
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatted = DateFormat('EEEE d. MMM', 'nb_NO').format(date.toLocal());

    return Row(
      children: [
        const Expanded(child: Divider(indent: 24, endIndent: 12, thickness: 0.6)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            formatted,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(child: Divider(indent: 12, endIndent: 24, thickness: 0.6)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.message_rounded,
              size: 48, color: theme.colorScheme.primary.withOpacity(0.6)),
          const SizedBox(height: 12),
          Text(
            'Si hei til kontaktpersonen din!',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Skriv din første melding i feltet under.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

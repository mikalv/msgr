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
          duration: const Duration(milliseconds: 320),
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

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: Stack(
        children: [
          ListView.builder(
            controller: _controller,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
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
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: _DayDivider(
                        date: message.insertedAt ?? DateTime.now(),
                      ),
                    ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.9, end: 1),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) => Transform.scale(
                      scale: value,
                      alignment:
                          isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: child,
                    ),
                    child: ChatBubble(message: message, isMine: isMine),
                  ),
                ],
              );
            },
          ),
          const _EdgeFade(alignment: Alignment.topCenter),
          const _EdgeFade(alignment: Alignment.bottomCenter),
        ],
      ),
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
            color: theme.colorScheme.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withOpacity(0.3),
            ),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.18),
                    theme.colorScheme.primary.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 42,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Si hei til kontaktpersonen din!',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Du er først i samtalen. Start dialogen med en vennlig melding.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Container(
          height: 36,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: alignment == Alignment.topCenter
                  ? Alignment.topCenter
                  : Alignment.bottomCenter,
              end: alignment == Alignment.topCenter
                  ? Alignment.bottomCenter
                  : Alignment.topCenter,
              colors: [
                theme.colorScheme.surface.withOpacity(0.92),
                theme.colorScheme.surface.withOpacity(0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

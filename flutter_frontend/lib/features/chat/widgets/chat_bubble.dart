import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:messngr/features/chat/models/chat_message.dart';
import 'package:messngr/features/chat/widgets/chat_theme.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.isMine,
  });

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timestamp = message.insertedAt ?? message.sentAt;
    final formattedTime = timestamp != null
        ? DateFormat.Hm().format(timestamp.toLocal())
        : '';

    final alignment = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(24),
      topRight: const Radius.circular(24),
      bottomLeft: isMine ? const Radius.circular(20) : const Radius.circular(8),
      bottomRight: isMine ? const Radius.circular(8) : const Radius.circular(20),
    );

    final background = isMine
        ? null
        : ChatTheme.otherBubbleColor(theme);

    final gradient = isMine ? ChatTheme.selfBubbleGradient(theme) : null;
    final textColor = isMine
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    return Align(
      alignment: alignment,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        margin: EdgeInsetsDirectional.only(
          start: isMine ? 80 : 8,
          end: isMine ? 8 : 80,
          top: 6,
          bottom: 6,
        ),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: gradient,
          color: background,
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isMine
                ? Colors.white.withOpacity(0.06)
                : background,
            borderRadius: borderRadius.deflate(const EdgeInsets.all(0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundColor:
                              theme.colorScheme.primary.withOpacity(0.6),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          message.profileName,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                SelectableText(
                  message.body,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: textColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (formattedTime.isNotEmpty)
                      Text(
                        formattedTime,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: textColor.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (isMine) ...[
                      const SizedBox(width: 6),
                      _StatusIcon(message: message),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (message.isLocal || message.status == 'sending') {
      return SizedBox.square(
        dimension: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.6,
          valueColor: AlwaysStoppedAnimation<Color>(
            theme.colorScheme.onPrimaryContainer.withOpacity(0.85),
          ),
        ),
      );
    }

    final color = theme.colorScheme.onPrimaryContainer;
    switch (message.status) {
      case 'sent':
        return Icon(Icons.check, size: 14, color: color);
      case 'delivered':
        return Icon(Icons.done_all, size: 14, color: color);
      case 'read':
        return Icon(Icons.done_all,
            size: 14, color: color.withOpacity(0.9));
      default:
        return const SizedBox.shrink();
    }
  }
}

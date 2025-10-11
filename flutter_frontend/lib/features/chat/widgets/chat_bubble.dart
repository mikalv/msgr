import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:messngr/features/chat/models/chat_message.dart';

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
    final radius = Radius.circular(22);

    final bubbleColor = isMine
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceVariant;
    final textColor = isMine
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;

    final timestamp = message.insertedAt ?? message.sentAt;
    final formattedTime = timestamp != null
        ? DateFormat.Hm().format(timestamp.toLocal())
        : '';

    final statusIcon = _statusIcon(theme);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.only(
        left: isMine ? 72 : 12,
        right: isMine ? 12 : 72,
        top: 6,
        bottom: 6,
      ),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: isMine
            ? LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.85),
                  theme.colorScheme.primaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isMine ? null : bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: radius,
          topRight: radius,
          bottomLeft: isMine ? radius : Radius.circular(6),
          bottomRight: isMine ? Radius.circular(6) : radius,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.profileName,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            SelectableText(
              message.body,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: textColor,
                height: 1.35,
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
                    ),
                  ),
                if (statusIcon != null) ...[
                  const SizedBox(width: 6),
                  statusIcon,
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget? _statusIcon(ThemeData theme) {
    if (!isMine) {
      return null;
    }
    if (message.isLocal || message.status == 'sending') {
      return SizedBox.square(
        dimension: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
          ),
        ),
      );
    }

    switch (message.status) {
      case 'sent':
        return Icon(Icons.check, size: 14, color: theme.colorScheme.onPrimaryContainer);
      case 'delivered':
        return Icon(Icons.done_all, size: 14, color: theme.colorScheme.onPrimaryContainer);
      case 'read':
        return Icon(Icons.done_all,
            size: 14, color: theme.colorScheme.onPrimaryContainer.withOpacity(0.9));
      default:
        return null;
    }
  }
}

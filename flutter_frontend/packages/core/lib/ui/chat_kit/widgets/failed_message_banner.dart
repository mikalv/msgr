import 'package:flutter/material.dart';

import 'package:core/providers/models.dart';
import 'message_status_indicator.dart';

/// Renders a failed message with greyed-out text and retry controls.
///
/// - Tap: retry immediately
/// - Long-press: context menu with Retry, Edit, Delete
class FailedMessageBanner extends StatelessWidget {
  const FailedMessageBanner({
    super.key,
    required this.message,
    required this.onRetry,
    this.onEdit,
    this.onDelete,
  });

  final SlackMessage message;
  final VoidCallback onRetry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onRetry,
      onLongPress: () => _showContextMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.error.withOpacity(0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.45),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kunne ikke sende — trykk for å prøve igjen',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            MessageStatusIndicator(
              status: MessageStatus.failed,
              onRetry: onRetry,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final theme = Theme.of(context);
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final RenderBox box = context.findRenderObject()! as RenderBox;
    final Offset position = box.localToGlobal(
      Offset(box.size.width / 2, box.size.height),
      ancestor: overlay,
    );

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx - 80,
        position.dy,
        position.dx + 80,
        position.dy + 120,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'retry',
          child: Row(
            children: [
              Icon(Icons.refresh, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Prøv igjen'),
            ],
          ),
        ),
        if (onEdit != null)
          PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined,
                    size: 18, color: theme.colorScheme.onSurface),
                const SizedBox(width: 8),
                const Text('Rediger'),
              ],
            ),
          ),
        if (onDelete != null)
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline,
                    size: 18, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Text('Slett',
                    style: TextStyle(color: theme.colorScheme.error)),
              ],
            ),
          ),
      ],
    ).then((value) {
      switch (value) {
        case 'retry':
          onRetry();
          break;
        case 'edit':
          onEdit?.call();
          break;
        case 'delete':
          onDelete?.call();
          break;
      }
    });
  }
}

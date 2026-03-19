import 'package:flutter/material.dart';

/// Indicator shown above the composer when there are messages waiting to send.
///
/// Displays a count like "3 meldinger venter på å bli sendt" along with a
/// subtle progress animation.
class OutgoingQueueIndicator extends StatelessWidget {
  const OutgoingQueueIndicator({
    super.key,
    required this.pendingCount,
  });

  /// Number of messages queued for sending.
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    if (pendingCount <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final label = pendingCount == 1
        ? '1 melding venter på å bli sendt'
        : '$pendingCount meldinger venter på å bli sendt';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

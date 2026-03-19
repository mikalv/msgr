import 'package:flutter/material.dart';

import 'package:core/providers/models.dart';

/// Displays delivery status for a sent message.
///
/// Visual states:
/// - [MessageStatus.sending] — animated spinner (small, subtle)
/// - [MessageStatus.sent] — single grey checkmark
/// - [MessageStatus.delivered] — double grey checkmarks
/// - [MessageStatus.read] — double blue checkmarks
/// - [MessageStatus.failed] — red error icon with optional "tap to retry"
class MessageStatusIndicator extends StatelessWidget {
  const MessageStatusIndicator({
    super.key,
    required this.status,
    this.onRetry,
    this.size = 16.0,
  });

  final MessageStatus status;

  /// Called when the user taps a failed message indicator.
  final VoidCallback? onRetry;

  /// Icon size. Defaults to 16.
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
          ),
        );

      case MessageStatus.sent:
        return Icon(
          Icons.check,
          size: size,
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
        );

      case MessageStatus.delivered:
        return _DoubleCheck(
          size: size,
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
        );

      case MessageStatus.read:
        return _DoubleCheck(
          size: size,
          color: theme.colorScheme.primary,
        );

      case MessageStatus.failed:
        return GestureDetector(
          onTap: onRetry,
          child: Tooltip(
            message: 'Sending feilet — trykk for å prøve igjen',
            child: Icon(
              Icons.error_outline,
              size: size,
              color: theme.colorScheme.error,
            ),
          ),
        );
    }
  }
}

/// Double checkmark icon built from two offset single checks.
class _DoubleCheck extends StatelessWidget {
  const _DoubleCheck({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.4,
      height: size,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: Icon(Icons.check, size: size, color: color),
          ),
          Positioned(
            left: size * 0.35,
            child: Icon(Icons.check, size: size, color: color),
          ),
        ],
      ),
    );
  }
}

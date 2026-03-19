import 'package:flutter/material.dart';

/// Yellow/amber banner shown at the top of the chat area when offline.
///
/// Informs the user that messages will be queued and sent when the
/// connection is restored. Dismissible via a close button.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    this.onDismiss,
  });

  /// Called when the user dismisses the banner. If null the close button
  /// is hidden and the banner is not dismissible.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = Colors.amber.shade100;
    final fgColor = Colors.amber.shade900;

    return Material(
      color: bgColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 18,
                color: fgColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Du er frakoblet — meldinger sendes når du er tilkoblet igjen',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: fgColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: fgColor),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  tooltip: 'Lukk',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

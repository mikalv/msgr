import 'package:flutter/material.dart';

class ConnectionStatusBanner extends StatelessWidget {
  const ConnectionStatusBanner({
    super.key,
    required this.isOnline,
    this.message,
    this.retry,
  });

  final bool isOnline;
  final String? message;
  final VoidCallback? retry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = message ??
        (isOnline
            ? 'Tilkoblet til nettverket igjen'
            : 'Du er frakoblet. Viser hurtigbuffer.');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: isOnline
            ? theme.colorScheme.secondary.withOpacity(0.16)
            : theme.colorScheme.error.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline
              ? theme.colorScheme.secondary.withOpacity(0.3)
              : theme.colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            size: 18,
            color: isOnline
                ? theme.colorScheme.secondary
                : theme.colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isOnline
                    ? theme.colorScheme.onSecondaryContainer
                    : theme.colorScheme.error,
              ),
            ),
          ),
          if (!isOnline && retry != null)
            TextButton(
              onPressed: retry,
              child: const Text('Forsøk igjen'),
            ),
        ],
      ),
    );
  }
}

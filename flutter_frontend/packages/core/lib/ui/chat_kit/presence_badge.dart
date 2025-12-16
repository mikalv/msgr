import 'package:flutter/material.dart';

class PresenceBadge extends StatelessWidget {
  const PresenceBadge({
    super.key,
    required this.isOnline,
    this.size = 12,
    this.color,
    this.showBorder = true,
  });

  final bool isOnline;
  final double size;
  final Color? color;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isOnline
            ? (color ?? theme.colorScheme.secondary)
            : theme.colorScheme.onSurface.withOpacity(0.38),
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(
                color: theme.colorScheme.surface,
                width: size * 0.18,
              )
            : null,
      ),
    );
  }
}

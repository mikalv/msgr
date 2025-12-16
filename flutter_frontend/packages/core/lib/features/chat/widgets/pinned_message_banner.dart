import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:messngr/features/chat/state/pinned_messages_notifier.dart';

class PinnedMessageBanner extends StatelessWidget {
  const PinnedMessageBanner({
    super.key,
    required this.pinned,
    this.onTap,
    this.isActive = false,
  });

  final List<PinnedMessageInfo> pinned;
  final VoidCallback? onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    if (pinned.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final formatter = DateFormat.Hm();
    final latest = pinned.first;
    final title = isActive ? 'Viser festede meldinger' : 'Festet melding';
    final subtitle = isActive
        ? 'Trykk for å vise alle meldinger igjen'
        : 'Festet ${formatter.format(latest.pinnedAt.toLocal())}';

    final banner = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.push_pin, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isActive ? 'Lukk' : 'Vis',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isActive ? Icons.close : Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ],
            ),
        ],
      ),
    );

    if (onTap == null) {
      return banner;
    }

    return GestureDetector(onTap: onTap, child: banner);
  }
}

import 'package:flutter/material.dart';
import 'package:messngr/features/chat/state/typing_participants_notifier.dart';

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key, required this.participants});

  final List<TypingParticipant> participants;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final names = participants.map((p) => p.profileName).toList();
    final text = _buildMessage(names);

    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }

  String _buildMessage(List<String> names) {
    if (names.length == 1) {
      return '${names.first} skriver…';
    }
    if (names.length == 2) {
      return '${names[0]} og ${names[1]} skriver…';
    }
    final head = names.take(2).join(', ');
    final remaining = names.length - 2;
    return '$head og $remaining andre skriver…';
  }
}

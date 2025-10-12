part of 'package:messngr/features/chat/widgets/chat_composer.dart';

class _MentionPalette extends StatelessWidget {
  const _MentionPalette({
    required this.mentions,
    required this.highlightedIndex,
    required this.query,
    required this.onSelect,
  });

  final List<ComposerMention> mentions;
  final int highlightedIndex;
  final String query;
  final ValueChanged<ComposerMention> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (mentions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.58),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Nevner: @$query',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (var i = 0; i < mentions.length; i++)
            InkWell(
              onTap: () => onSelect(mentions[i]),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(i == 0 ? 18 : 0),
                bottom: Radius.circular(i == mentions.length - 1 ? 18 : 0),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: i == highlightedIndex
                      ? theme.colorScheme.primary.withOpacity(0.12)
                      : Colors.transparent,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          theme.colorScheme.primary.withOpacity(0.18),
                      child: Text(
                        mentions[i].initials,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mentions[i].displayName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '@${mentions[i].handle}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.keyboard_return, size: 16),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommandPalette extends StatelessWidget {
  const _CommandPalette({
    required this.commands,
    required this.highlightedIndex,
    required this.onSelect,
  });

  final List<SlashCommand> commands;
  final int highlightedIndex;
  final ValueChanged<SlashCommand> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < commands.length; i++)
            _CommandTile(
              command: commands[i],
              isHighlighted: i == highlightedIndex,
              onTap: () => onSelect(commands[i]),
            ),
        ],
      ),
    );
  }
}

class _CommandTile extends StatelessWidget {
  const _CommandTile({
    required this.command,
    required this.isHighlighted,
    required this.onTap,
  });

  final SlashCommand command;
  final bool isHighlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isHighlighted
          ? theme.colorScheme.primary.withOpacity(0.12)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                command.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  command.description,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmojiPicker extends StatelessWidget {
  const _EmojiPicker({required this.onSelect});

  static const _emoji = [
    '😀',
    '😁',
    '😂',
    '🤣',
    '😅',
    '😊',
    '😍',
    '🤩',
    '😎',
    '🤔',
    '🙌',
    '👍',
    '👏',
    '🙏',
    '🔥',
    '🎉',
    '💡',
    '🚀',
    '❤️',
    '🤝',
  ];

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final emoji in _emoji)
            GestureDetector(
              onTap: () => onSelect(emoji),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
        ],
      ),
    );
  }
}

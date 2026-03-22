part of 'simple_chat_content.dart';

// ---------------------------------------------------------------------------
// Reaction bar + pills
// ---------------------------------------------------------------------------

/// Row of reaction pills below a message, with a '+' button to add new ones.
class _ReactionBar extends StatelessWidget {
  const _ReactionBar({
    super.key,
    required this.reactions,
    required this.onToggle,
  });

  final List<MessageReaction> reactions;
  final ValueChanged<String> onToggle;

  static const _quickEmoji = [
    '\u{1F44D}', '\u{2764}\u{FE0F}', '\u{1F602}', '\u{1F389}',
    '\u{2705}', '\u{1F440}', '\u{1F525}', '\u{1F4AF}',
    '\u{1F680}', '\u{1F64F}', '\u{1F914}', '\u{1F60D}',
    '\u{1F44F}', '\u{1F929}', '\u{1F4A1}', '\u{2615}\u{FE0F}',
    '\u{1F31F}', '\u{1F3B5}', '\u{1F4AA}', '\u{1F60E}',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final reaction in reactions)
            _ReactionPill(
              emoji: reaction.emoji,
              count: reaction.count,
              isActive: reaction.includesMe,
              onTap: () => onToggle(reaction.emoji),
            ),
          _AddReactionButton(
            onSelected: onToggle,
            quickEmoji: _quickEmoji,
          ),
        ],
      ),
    );
  }
}

/// A compact reaction pill: [emoji count] with highlighted border if user reacted.
class _ReactionPill extends StatelessWidget {
  const _ReactionPill({
    super.key,
    required this.emoji,
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF02ac88).withOpacity(0.25)
                : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF02ac88).withOpacity(0.6)
                  : Colors.white.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 3),
              Text(
                '$count',
                style: TextStyle(
                  color: isActive ? const Color(0xFF02ac88) : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small '+' button that opens a simple emoji grid popup.
class _AddReactionButton extends StatelessWidget {
  const _AddReactionButton({
    super.key,
    required this.onSelected,
    required this.quickEmoji,
  });

  final ValueChanged<String> onSelected;
  final List<String> quickEmoji;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showPicker(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.add_reaction_outlined,
            size: 14,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final position = box.localToGlobal(Offset.zero, ancestor: overlay);

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy - 180,
        position.dx + 280,
        position.dy,
      ),
      constraints: const BoxConstraints(maxWidth: 280, maxHeight: 200),
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 260,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final emoji in quickEmoji)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(emoji),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child:
                            Text(emoji, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );

    if (selected != null) {
      onSelected(selected);
    }
  }
}

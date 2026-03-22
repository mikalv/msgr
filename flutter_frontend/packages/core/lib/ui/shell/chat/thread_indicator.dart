part of 'simple_chat_content.dart';

// ---------------------------------------------------------------------------
// Thread indicator
// ---------------------------------------------------------------------------

class _ThreadIndicator extends StatefulWidget {
  const _ThreadIndicator({
    required this.replyCount,
    required this.onTap,
  });

  final int replyCount;
  final VoidCallback onTap;

  @override
  State<_ThreadIndicator> createState() => _ThreadIndicatorState();
}

class _ThreadIndicatorState extends State<_ThreadIndicator> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.forum_outlined,
                size: 14,
                color: _hovered
                    ? const Color(0xFF4FC3F7)
                    : const Color(0xFF4FC3F7).withOpacity(0.7),
              ),
              const SizedBox(width: 4),
              Text(
                '${widget.replyCount} svar',
                style: TextStyle(
                  color: _hovered
                      ? const Color(0xFF4FC3F7)
                      : const Color(0xFF4FC3F7).withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration:
                      _hovered ? TextDecoration.underline : TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

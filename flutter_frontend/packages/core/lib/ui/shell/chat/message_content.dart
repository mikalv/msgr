part of 'simple_chat_content.dart';

// ---------------------------------------------------------------------------
// Message content: markdown rendering + auto-link fallback
// ---------------------------------------------------------------------------

class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.content,
    required this.status,
    this.mentions = const [],
  });

  final String content;
  final MessageStatus status;
  final List<MentionData> mentions;

  /// Returns true if the text likely contains markdown formatting.
  bool get _hasMarkdown {
    return content.contains('**') ||
        content.contains('__') ||
        content.contains('*') ||
        content.contains('~~') ||
        content.contains('```') ||
        content.contains('`') ||
        content.contains('- ') ||
        content.contains('* ') ||
        content.contains('[') ||
        content.contains('# ');
  }

  Color _textColor() {
    if (status == MessageStatus.sending) return Colors.white.withOpacity(0.4);
    if (status == MessageStatus.failed) {
      return Colors.redAccent.withOpacity(0.6);
    }
    return Colors.white.withOpacity(0.9);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasMarkdown && mentions.isEmpty) {
      return MarkdownBody(
        data: content,
        selectable: true,
        onTapLink: (text, href, title) {
          if (href != null) {
            launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
          }
        },
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(color: _textColor(), fontSize: 14, height: 1.4),
          strong: TextStyle(
              color: _textColor(),
              fontSize: 14,
              fontWeight: FontWeight.w700),
          em: TextStyle(
              color: _textColor(),
              fontSize: 14,
              fontStyle: FontStyle.italic),
          del: TextStyle(
              color: _textColor(),
              fontSize: 14,
              decoration: TextDecoration.lineThrough),
          code: TextStyle(
            color: const Color(0xFFE8E8E8),
            backgroundColor: Colors.white.withOpacity(0.08),
            fontSize: 13,
            fontFamily: 'monospace',
          ),
          codeblockDecoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          codeblockPadding: const EdgeInsets.all(10),
          codeblockAlign: WrapAlignment.start,
          blockquoteDecoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                  color: Colors.white.withOpacity(0.3), width: 3),
            ),
          ),
          blockquotePadding:
              const EdgeInsets.only(left: 12, top: 4, bottom: 4),
          a: const TextStyle(
            color: Color(0xFF4FC3F7),
            decoration: TextDecoration.underline,
            fontSize: 14,
          ),
          listBullet: TextStyle(color: _textColor(), fontSize: 14),
          h1: TextStyle(
              color: _textColor(),
              fontSize: 20,
              fontWeight: FontWeight.w700),
          h2: TextStyle(
              color: _textColor(),
              fontSize: 18,
              fontWeight: FontWeight.w700),
          h3: TextStyle(
              color: _textColor(),
              fontSize: 16,
              fontWeight: FontWeight.w700),
        ),
      );
    }

    // Plain text with auto-linked URLs + mention highlighting
    return _LinkedText(
      content: content,
      color: _textColor(),
      mentions: mentions,
    );
  }
}

// ---------------------------------------------------------------------------
// Auto-linked plain text
// ---------------------------------------------------------------------------

/// Regex to detect @mentions in plain text (fallback when no structured data).
final _mentionRegex = RegExp(r'@[\w.]+');

class _LinkedText extends ConsumerWidget {
  const _LinkedText({
    required this.content,
    required this.color,
    this.mentions = const [],
  });

  final String content;
  final Color color;
  final List<MentionData> mentions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseStyle = TextStyle(color: color, fontSize: 14, height: 1.4);

    // Build a set of highlighted ranges from structured mention data.
    // If no structured mentions exist, fall back to regex detection.
    final highlightRanges = <_HighlightRange>[];

    if (mentions.isNotEmpty) {
      for (final m in mentions) {
        if (m.offset >= 0 && m.offset + m.length <= content.length) {
          highlightRanges.add(_HighlightRange(
            start: m.offset,
            end: m.offset + m.length,
            name: m.displayName,
            profileId: m.profileId,
          ));
        }
      }
    } else {
      // Regex fallback: detect @word patterns in text.
      for (final match in _mentionRegex.allMatches(content)) {
        highlightRanges.add(_HighlightRange(
          start: match.start,
          end: match.end,
          name: content.substring(match.start + 1, match.end),
        ));
      }
    }

    // Merge URL matches and mention highlights into a single sorted list
    // of "special" ranges, then build spans.
    final urlMatches = _urlRegex.allMatches(content).toList();

    // Combine all special ranges (urls + mentions), sorted by start.
    final allRanges = <_TextRange>[];
    for (final m in urlMatches) {
      allRanges.add(_TextRange(start: m.start, end: m.end, kind: _RangeKind.url));
    }
    for (final h in highlightRanges) {
      allRanges.add(_TextRange(start: h.start, end: h.end, kind: _RangeKind.mention, name: h.name, profileId: h.profileId));
    }
    allRanges.sort((a, b) => a.start.compareTo(b.start));

    // Remove overlapping ranges (first-come wins).
    final resolved = <_TextRange>[];
    var occupiedUntil = 0;
    for (final r in allRanges) {
      if (r.start >= occupiedUntil) {
        resolved.add(r);
        occupiedUntil = r.end;
      }
    }

    if (resolved.isEmpty) {
      return Text(content, style: baseStyle);
    }

    final spans = <InlineSpan>[];
    var lastEnd = 0;

    for (final range in resolved) {
      if (range.start > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, range.start),
          style: baseStyle,
        ));
      }

      final segment = content.substring(range.start, range.end);

      if (range.kind == _RangeKind.url) {
        spans.add(TextSpan(
          text: segment,
          style: const TextStyle(
            color: Color(0xFF4FC3F7),
            decoration: TextDecoration.underline,
            fontSize: 14,
            height: 1.4,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              launchUrl(Uri.parse(segment), mode: LaunchMode.externalApplication);
            },
        ));
      } else {
        // Mention pill-style highlight.
        final mentionColor = _colorForName(range.name ?? segment);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: range.profileId != null
                ? () => showProfileCardById(context, ref, profileId: range.profileId!)
                : null,
            child: MouseRegion(
              cursor: range.profileId != null
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.text,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: mentionColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  segment,
                  style: TextStyle(
                    color: mentionColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ));
      }

      lastEnd = range.end;
    }

    if (lastEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return SelectableText.rich(TextSpan(children: spans));
  }
}

enum _RangeKind { url, mention }

class _TextRange {
  const _TextRange({
    required this.start,
    required this.end,
    required this.kind,
    this.name,
    this.profileId,
  });
  final int start;
  final int end;
  final _RangeKind kind;
  final String? name;
  final String? profileId;
}

class _HighlightRange {
  const _HighlightRange({
    required this.start,
    required this.end,
    required this.name,
    this.profileId,
  });
  final int start;
  final int end;
  final String name;
  final String? profileId;
}

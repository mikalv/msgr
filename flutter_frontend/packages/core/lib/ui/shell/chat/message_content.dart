part of 'simple_chat_content.dart';

// ---------------------------------------------------------------------------
// Message content: markdown rendering + auto-link fallback
// ---------------------------------------------------------------------------

/// Monokai-inspired dark theme for code blocks.
const _codeTheme = {
  'root': TextStyle(color: Color(0xFFF8F8F2), backgroundColor: Color(0xFF1E1E1E)),
  'keyword': TextStyle(color: Color(0xFFF92672)),
  'built_in': TextStyle(color: Color(0xFF66D9EF)),
  'type': TextStyle(color: Color(0xFF66D9EF)),
  'literal': TextStyle(color: Color(0xFFAE81FF)),
  'number': TextStyle(color: Color(0xFFAE81FF)),
  'string': TextStyle(color: Color(0xFFE6DB74)),
  'symbol': TextStyle(color: Color(0xFFE6DB74)),
  'regexp': TextStyle(color: Color(0xFFE6DB74)),
  'title': TextStyle(color: Color(0xFFA6E22E)),
  'function': TextStyle(color: Color(0xFFA6E22E)),
  'section': TextStyle(color: Color(0xFFA6E22E)),
  'selector-class': TextStyle(color: Color(0xFFA6E22E)),
  'attribute': TextStyle(color: Color(0xFFA6E22E)),
  'attr': TextStyle(color: Color(0xFFA6E22E)),
  'variable': TextStyle(color: Color(0xFFF8F8F2)),
  'params': TextStyle(color: Color(0xFFF8F8F2)),
  'comment': TextStyle(color: Color(0xFF75715E)),
  'doctag': TextStyle(color: Color(0xFF75715E)),
  'meta': TextStyle(color: Color(0xFF75715E)),
  'meta-keyword': TextStyle(color: Color(0xFFF92672)),
  'meta-string': TextStyle(color: Color(0xFFE6DB74)),
  'addition': TextStyle(color: Color(0xFFA6E22E)),
  'deletion': TextStyle(color: Color(0xFFF92672)),
  'subst': TextStyle(color: Color(0xFFF8F8F2)),
  'tag': TextStyle(color: Color(0xFFF92672)),
  'name': TextStyle(color: Color(0xFFF92672)),
};

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
        builders: {
          'code': _CodeBlockBuilder(),
        },
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
          codeblockDecoration: const BoxDecoration(),
          codeblockPadding: EdgeInsets.zero,
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
// Syntax-highlighted code block builder for flutter_markdown
// ---------------------------------------------------------------------------

class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent.trimRight();
    final language = _extractLanguage(element);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (language != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
              child: Text(
                language,
                style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: HighlightView(
              code,
              language: language ?? 'plaintext',
              theme: _codeTheme,
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  String? _extractLanguage(md.Element element) {
    // flutter_markdown passes the language in the element's attributes
    final className = element.attributes['class'];
    if (className != null && className.startsWith('language-')) {
      return className.substring('language-'.length);
    }
    return null;
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
      return SelectableText(content, style: baseStyle);
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

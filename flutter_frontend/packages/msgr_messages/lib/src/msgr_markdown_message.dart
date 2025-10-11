import 'package:meta/meta.dart';

import 'msgr_message.dart';
import 'msgr_theme.dart';

/// Markdown formatted message with optional trusted rendering.
@immutable
class MsgrMarkdownMessage extends MsgrAuthoredMessage {
  /// Creates a markdown message.
  const MsgrMarkdownMessage({
    required super.id,
    required this.markdown,
    this.isTrusted = false,
    required super.profileId,
    required super.profileName,
    required super.profileMode,
    super.status,
    super.sentAt,
    super.insertedAt,
    super.isLocal,
    super.theme,
  }) : super(kind: MsgrMessageKind.markdown);

  /// Raw markdown payload.
  final String markdown;

  /// Whether the markdown is pre-sanitised by the backend.
  final bool isTrusted;

  /// Creates a copy with selectively overridden fields.
  MsgrMarkdownMessage copyWith({
    String? id,
    String? markdown,
    bool? isTrusted,
    String? profileId,
    String? profileName,
    String? profileMode,
    String? status,
    DateTime? sentAt,
    DateTime? insertedAt,
    bool? isLocal,
    MsgrMessageTheme? theme,
  }) {
    return MsgrMarkdownMessage(
      id: id ?? this.id,
      markdown: markdown ?? this.markdown,
      isTrusted: isTrusted ?? this.isTrusted,
      profileId: profileId ?? this.profileId,
      profileName: profileName ?? this.profileName,
      profileMode: profileMode ?? this.profileMode,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
      insertedAt: insertedAt ?? this.insertedAt,
      isLocal: isLocal ?? this.isLocal,
      theme: theme ?? this.theme,
    );
  }

  /// Creates a [MsgrMarkdownMessage] from a JSON compatible map.
  factory MsgrMarkdownMessage.fromMap(Map<String, dynamic> map) {
    final author = MsgrAuthoredMessage.readAuthorMap(map);
    return MsgrMarkdownMessage(
      id: map['id'] as String,
      markdown: map['markdown'] as String? ?? map['body'] as String? ?? '',
      isTrusted: map['isTrusted'] as bool? ?? false,
      profileId: author.profileId,
      profileName: author.profileName,
      profileMode: author.profileMode,
      status: author.status,
      sentAt: author.sentAt,
      insertedAt: author.insertedAt,
      isLocal: author.isLocal,
      theme: MsgrMessage.readTheme(map),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': kind.name,
      'id': id,
      'markdown': markdown,
      'isTrusted': isTrusted,
      ...toAuthorMap(),
      'sentAt': MsgrMessage.encodeTimestamp(sentAt),
      'insertedAt': MsgrMessage.encodeTimestamp(insertedAt),
      'isLocal': isLocal,
      'theme': theme.toMap(),
    };
  }

  @override
  List<Object?> get props => [
        ...super.props,
        markdown,
        isTrusted,
      ];

  @override
  MsgrMarkdownMessage themed(MsgrMessageTheme theme) => copyWith(theme: theme);
}

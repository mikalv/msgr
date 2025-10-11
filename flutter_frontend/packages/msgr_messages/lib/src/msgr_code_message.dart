import 'package:meta/meta.dart';

import 'msgr_message.dart';
import 'msgr_theme.dart';

/// Code snippet message with optional syntax information.
@immutable
class MsgrCodeMessage extends MsgrAuthoredMessage {
  /// Creates a code snippet message.
  const MsgrCodeMessage({
    required super.id,
    required this.code,
    this.language = 'plaintext',
    this.caption,
    required super.profileId,
    required super.profileName,
    required super.profileMode,
    super.status,
    super.sentAt,
    super.insertedAt,
    super.isLocal,
    super.theme,
  }) : super(kind: MsgrMessageKind.code);

  /// Source code contents for the snippet.
  final String code;

  /// Preferred syntax highlighter language key.
  final String language;

  /// Optional caption describing the snippet.
  final String? caption;

  /// Creates a copy with selectively overridden fields.
  MsgrCodeMessage copyWith({
    String? id,
    String? code,
    String? language,
    String? caption,
    String? profileId,
    String? profileName,
    String? profileMode,
    String? status,
    DateTime? sentAt,
    DateTime? insertedAt,
    bool? isLocal,
    MsgrMessageTheme? theme,
  }) {
    return MsgrCodeMessage(
      id: id ?? this.id,
      code: code ?? this.code,
      language: language ?? this.language,
      caption: caption ?? this.caption,
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

  /// Creates a [MsgrCodeMessage] from a JSON compatible map.
  factory MsgrCodeMessage.fromMap(Map<String, dynamic> map) {
    final author = MsgrAuthoredMessage.readAuthorMap(map);
    return MsgrCodeMessage(
      id: map['id'] as String,
      code: map['code'] as String? ?? '',
      language: map['language'] as String? ?? 'plaintext',
      caption: map['caption'] as String?,
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
      'code': code,
      'language': language,
      'caption': caption,
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
        code,
        language,
        caption,
      ];

  @override
  MsgrCodeMessage themed(MsgrMessageTheme theme) => copyWith(theme: theme);
}

import 'package:meta/meta.dart';

import 'msgr_message.dart';
import 'msgr_theme.dart';

/// Image based message with metadata for rendering thumbnails.
@immutable
class MsgrImageMessage extends MsgrAuthoredMessage {
  /// Creates an image message referencing remote resources.
  const MsgrImageMessage({
    required super.id,
    required this.url,
    this.thumbnailUrl,
    this.description,
    this.width,
    this.height,
    required super.profileId,
    required super.profileName,
    required super.profileMode,
    super.status,
    super.sentAt,
    super.insertedAt,
    super.isLocal,
    super.theme,
  }) : super(kind: MsgrMessageKind.image);

  /// Full resolution image URL.
  final String url;

  /// Optional thumbnail preview URL.
  final String? thumbnailUrl;

  /// Description or alt text for accessibility.
  final String? description;

  /// Pixel width of the image.
  final int? width;

  /// Pixel height of the image.
  final int? height;

  /// Creates a copy with selectively overridden fields.
  MsgrImageMessage copyWith({
    String? id,
    String? url,
    String? thumbnailUrl,
    String? description,
    int? width,
    int? height,
    String? profileId,
    String? profileName,
    String? profileMode,
    String? status,
    DateTime? sentAt,
    DateTime? insertedAt,
    bool? isLocal,
    MsgrMessageTheme? theme,
  }) {
    return MsgrImageMessage(
      id: id ?? this.id,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      description: description ?? this.description,
      width: width ?? this.width,
      height: height ?? this.height,
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

  /// Recreates an [MsgrImageMessage] from a JSON compatible map.
  factory MsgrImageMessage.fromMap(Map<String, dynamic> map) {
    final author = MsgrAuthoredMessage.readAuthorMap(map);
    return MsgrImageMessage(
      id: map['id'] as String,
      url: map['url'] as String? ?? '',
      thumbnailUrl: map['thumbnailUrl'] as String? ?? map['thumbnail'] as String?,
      description: map['description'] as String?,
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
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
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'description': description,
      'width': width,
      'height': height,
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
        url,
        thumbnailUrl,
        description,
        width,
        height,
      ];

  @override
  MsgrImageMessage themed(MsgrMessageTheme theme) => copyWith(theme: theme);
}

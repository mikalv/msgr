import 'package:meta/meta.dart';

import 'msgr_message.dart';
import 'msgr_theme.dart';

/// Generic file attachment message containing metadata for downloads.
@immutable
class MsgrFileMessage extends MsgrAuthoredMessage {
  /// Creates a new file message.
  const MsgrFileMessage({
    required super.id,
    required this.url,
    required this.fileName,
    this.mimeType,
    this.byteSize,
    this.caption,
    required super.profileId,
    required super.profileName,
    required super.profileMode,
    super.status,
    super.sentAt,
    super.insertedAt,
    super.isLocal,
    super.theme,
  }) : super(kind: MsgrMessageKind.file);

  /// Public URL used to download the file attachment.
  final String url;

  /// Name of the file presented to the user.
  final String fileName;

  /// Optional MIME type reported by the backend.
  final String? mimeType;

  /// File size in bytes.
  final int? byteSize;

  /// Optional caption supplied by the author.
  final String? caption;

  /// Recreates a [MsgrFileMessage] from a serialised map.
  factory MsgrFileMessage.fromMap(Map<String, dynamic> map) {
    final author = MsgrAuthoredMessage.readAuthorMap(map);
    return MsgrFileMessage(
      id: map['id'] as String,
      url: map['url'] as String? ?? '',
      fileName: map['fileName'] as String? ?? map['name'] as String? ?? '',
      mimeType: map['mimeType'] as String? ?? map['contentType'] as String?,
      byteSize: (map['byteSize'] as num?)?.toInt(),
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

  /// Creates a copy with the provided overrides.
  MsgrFileMessage copyWith({
    String? id,
    String? url,
    String? fileName,
    String? mimeType,
    int? byteSize,
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
    return MsgrFileMessage(
      id: id ?? this.id,
      url: url ?? this.url,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      byteSize: byteSize ?? this.byteSize,
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

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': kind.name,
      'id': id,
      'url': url,
      'fileName': fileName,
      'mimeType': mimeType,
      'byteSize': byteSize,
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
        url,
        fileName,
        mimeType,
        byteSize,
        caption,
      ];

  @override
  MsgrFileMessage themed(MsgrMessageTheme theme) => copyWith(theme: theme);
}

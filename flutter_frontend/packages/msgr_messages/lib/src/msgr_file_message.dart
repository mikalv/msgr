import 'package:meta/meta.dart';

import 'msgr_message.dart';
import 'msgr_theme.dart';

/// Generic file attachment message with optional preview metadata.
@immutable
class MsgrFileMessage extends MsgrAuthoredMessage {
  /// Creates a new file attachment message.
  const MsgrFileMessage({
    required super.id,
    required this.url,
    required this.fileName,
    this.byteSize,
    this.mimeType,
    this.caption,
    this.checksum,
    this.thumbnailUrl,
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
  /// Download URL for the file resource.
  final String url;

  /// Original filename supplied by the uploader.
  final String fileName;

  /// Total size of the file in bytes, when available.
  final int? byteSize;

  /// MIME type describing the contents of the file.
  final String? mimeType;

  /// Optional caption or description associated with the file.
  final String? caption;

  /// Optional checksum for integrity validation.
  final String? checksum;

  /// Optional thumbnail preview for the file (e.g. PDF poster).
  final String? thumbnailUrl;

  /// Creates a copy with selectively overridden fields.
  MsgrFileMessage copyWith({
    String? id,
    String? url,
    String? fileName,
    String? mimeType,
    int? byteSize,
    String? caption,
    int? byteSize,
    String? mimeType,
    String? caption,
    String? checksum,
    String? thumbnailUrl,
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
      byteSize: byteSize ?? this.byteSize,
      mimeType: mimeType ?? this.mimeType,
      caption: caption ?? this.caption,
      checksum: checksum ?? this.checksum,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
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

  /// Recreates a [MsgrFileMessage] from a serialised payload.
  factory MsgrFileMessage.fromMap(Map<String, dynamic> map) {
    final author = MsgrAuthoredMessage.readAuthorMap(map);
    return MsgrFileMessage(
      id: map['id'] as String,
      url: map['url'] as String? ?? '',
      fileName: map['fileName'] as String? ?? map['name'] as String? ?? '',
      byteSize: (map['byteSize'] as num?)?.toInt(),
      mimeType: map['mimeType'] as String? ?? map['contentType'] as String?,
      caption: map['caption'] as String?,
      checksum: map['checksum'] as String?,
      thumbnailUrl: map['thumbnailUrl'] as String? ?? map['thumbnail'] as String?,
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
      'fileName': fileName,
      'byteSize': byteSize,
      'mimeType': mimeType,
      'caption': caption,
      'checksum': checksum,
      'thumbnailUrl': thumbnailUrl,
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
        byteSize,
        mimeType,
        caption,
        checksum,
        thumbnailUrl,
      ];

  @override
  MsgrFileMessage themed(MsgrMessageTheme theme) => copyWith(theme: theme);
}

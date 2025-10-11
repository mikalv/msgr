import 'package:meta/meta.dart';

import 'msgr_message.dart';
import 'msgr_theme.dart';

/// Video media message containing playback metadata.
@immutable
class MsgrVideoMessage extends MsgrAuthoredMessage {
  /// Creates a video message entry.
  const MsgrVideoMessage({
    required super.id,
    required this.url,
    this.thumbnailUrl,
    this.thumbnailWidth,
    this.thumbnailHeight,
    this.caption,
    this.duration,
    this.autoplay = false,
    required super.profileId,
    required super.profileName,
    required super.profileMode,
    super.status,
    super.sentAt,
    super.insertedAt,
    super.isLocal,
    super.theme,
  }) : super(kind: MsgrMessageKind.video);

  /// Streaming URL for the video resource.
  final String url;

  /// Poster image used before playback starts.
  final String? thumbnailUrl;

  /// Width of the provided thumbnail preview.
  final int? thumbnailWidth;

  /// Height of the provided thumbnail preview.
  final int? thumbnailHeight;

  /// Optional caption describing the clip.
  final String? caption;

  /// Duration of the clip in seconds.
  final double? duration;

  /// Whether the video should auto-play in the UI.
  final bool autoplay;

  /// Creates a copy with selectively overridden fields.
  MsgrVideoMessage copyWith({
    String? id,
    String? url,
    String? thumbnailUrl,
    int? thumbnailWidth,
    int? thumbnailHeight,
    String? caption,
    double? duration,
    bool? autoplay,
    String? profileId,
    String? profileName,
    String? profileMode,
    String? status,
    DateTime? sentAt,
    DateTime? insertedAt,
    bool? isLocal,
    MsgrMessageTheme? theme,
  }) {
    return MsgrVideoMessage(
      id: id ?? this.id,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      thumbnailWidth: thumbnailWidth ?? this.thumbnailWidth,
      thumbnailHeight: thumbnailHeight ?? this.thumbnailHeight,
      caption: caption ?? this.caption,
      duration: duration ?? this.duration,
      autoplay: autoplay ?? this.autoplay,
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

  /// Recreates an [MsgrVideoMessage] from a JSON compatible map.
  factory MsgrVideoMessage.fromMap(Map<String, dynamic> map) {
    final author = MsgrAuthoredMessage.readAuthorMap(map);
    final rawThumbnail = map['thumbnail'];
    String? thumbnailUrl = map['thumbnailUrl'] as String?;
    if (thumbnailUrl == null && rawThumbnail is Map<String, dynamic>) {
      thumbnailUrl = rawThumbnail['url'] as String? ?? rawThumbnail['thumbnailUrl'] as String?;
    } else if (thumbnailUrl == null && rawThumbnail is String) {
      thumbnailUrl = rawThumbnail;
    }

    int? thumbnailWidth = (map['thumbnailWidth'] as num?)?.toInt();
    int? thumbnailHeight = (map['thumbnailHeight'] as num?)?.toInt();
    if (rawThumbnail is Map<String, dynamic>) {
      thumbnailWidth ??= (rawThumbnail['width'] as num?)?.toInt();
      thumbnailHeight ??= (rawThumbnail['height'] as num?)?.toInt();
    }

    return MsgrVideoMessage(
      id: map['id'] as String,
      url: map['url'] as String? ?? '',
      thumbnailUrl: thumbnailUrl,
      thumbnailWidth: thumbnailWidth,
      thumbnailHeight: thumbnailHeight,
      caption: map['caption'] as String?,
      duration: (map['duration'] as num?)?.toDouble(),
      autoplay: map['autoplay'] as bool? ?? false,
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
      'thumbnailWidth': thumbnailWidth,
      'thumbnailHeight': thumbnailHeight,
      'caption': caption,
      'duration': duration,
      'autoplay': autoplay,
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
        thumbnailWidth,
        thumbnailHeight,
        caption,
        duration,
        autoplay,
      ];

  @override
  MsgrVideoMessage themed(MsgrMessageTheme theme) => copyWith(theme: theme);
}

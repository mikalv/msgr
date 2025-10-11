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
    return MsgrVideoMessage(
      id: map['id'] as String,
      url: map['url'] as String? ?? '',
      thumbnailUrl: map['thumbnailUrl'] as String? ?? map['thumbnail'] as String?,
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
        caption,
        duration,
        autoplay,
      ];

  @override
  MsgrVideoMessage themed(MsgrMessageTheme theme) => copyWith(theme: theme);
}

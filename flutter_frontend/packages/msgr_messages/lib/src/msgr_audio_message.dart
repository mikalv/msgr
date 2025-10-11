import 'package:meta/meta.dart';

import 'msgr_message.dart';
import 'msgr_theme.dart';

/// Audio message with playback metadata and waveform support.
@immutable
class MsgrAudioMessage extends MsgrAuthoredMessage {
  /// Creates a new audio message entry.
  const MsgrAudioMessage({
    required super.id,
    required this.url,
    this.caption,
    this.duration,
    this.waveform,
    this.mimeType,
    this.waveformSampleRate,
    MsgrMessageKind kind = MsgrMessageKind.audio,
    super.status,
    required super.profileId,
    required super.profileName,
    required super.profileMode,
    super.sentAt,
    super.insertedAt,
    super.isLocal,
    super.theme,
    MsgrMessageKind kind = MsgrMessageKind.audio,
  })  : assert(kind == MsgrMessageKind.audio || kind == MsgrMessageKind.voice),
        super(kind: kind);

  /// Public playback URL for the audio resource.
  final String url;

  /// Optional caption associated with the clip.
  final String? caption;

  /// Duration of the audio in seconds.
  final double? duration;

  /// Optional normalised waveform samples (0-1).
  final List<double>? waveform;

  /// MIME type for the stored resource.
  final String? mimeType;

  /// Sample rate used when generating the waveform, if provided.
  final int? waveformSampleRate;

  /// Creates a copy with the provided overrides.
  MsgrAudioMessage copyWith({
    String? id,
    String? url,
    String? caption,
    double? duration,
    List<double>? waveform,
    String? mimeType,
    int? waveformSampleRate,
    MsgrMessageKind? kind,
    String? profileId,
    String? profileName,
    String? profileMode,
    String? status,
    DateTime? sentAt,
    DateTime? insertedAt,
    bool? isLocal,
    MsgrMessageTheme? theme,
    MsgrMessageKind? kind,
  }) {
    final resolvedKind = kind ?? this.kind;
    assert(resolvedKind == MsgrMessageKind.audio ||
        resolvedKind == MsgrMessageKind.voice);
    return MsgrAudioMessage(
      id: id ?? this.id,
      url: url ?? this.url,
      caption: caption ?? this.caption,
      duration: duration ?? this.duration,
      waveform: waveform ?? this.waveform,
      mimeType: mimeType ?? this.mimeType,
      waveformSampleRate: waveformSampleRate ?? this.waveformSampleRate,
      kind: resolvedKind,
      profileId: profileId ?? this.profileId,
      profileName: profileName ?? this.profileName,
      profileMode: profileMode ?? this.profileMode,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
      insertedAt: insertedAt ?? this.insertedAt,
      isLocal: isLocal ?? this.isLocal,
      theme: theme ?? this.theme,
      kind: kind ?? this.kind,
    );
  }

  /// Recreates an [MsgrAudioMessage] from a serialised map.
  factory MsgrAudioMessage.fromMap(Map<String, dynamic> map) {
    final author = MsgrAuthoredMessage.readAuthorMap(map);
    final type = map['type'] as String? ?? 'audio';
    final kind = type == 'voice' ? MsgrMessageKind.voice : MsgrMessageKind.audio;
    final type = map['type'] as String?;
    final kind = type == MsgrMessageKind.voice.name
        ? MsgrMessageKind.voice
        : MsgrMessageKind.audio;
    final waveform = (map['waveform'] as List?)
        ?.map((value) => (value as num).toDouble())
        .toList(growable: false);

    final rawDuration = map['duration'];
    double? durationSeconds;
    if (rawDuration is num) {
      durationSeconds = rawDuration.toDouble();
    } else {
      final durationMs = map['durationMs'];
      if (durationMs is num) {
        durationSeconds = durationMs.toDouble() / 1000;
      }
    }

    return MsgrAudioMessage(
      id: map['id'] as String,
      url: map['url'] as String? ?? '',
      caption: map['caption'] as String?,
      duration: durationSeconds,
      waveform: waveform,
      mimeType: map['mimeType'] as String? ?? map['contentType'] as String?,
      waveformSampleRate: (map['waveformSampleRate'] as num?)?.toInt(),
      kind: kind,
      profileId: author.profileId,
      profileName: author.profileName,
      profileMode: author.profileMode,
      status: author.status,
      sentAt: author.sentAt,
      insertedAt: author.insertedAt,
      isLocal: author.isLocal,
      theme: MsgrMessage.readTheme(map),
      kind: kind,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': kind.name,
      'id': id,
      'url': url,
      'caption': caption,
      'duration': duration,
      'waveform': waveform,
      'mimeType': mimeType,
      'waveformSampleRate': waveformSampleRate,
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
        caption,
        duration,
        waveform,
        mimeType,
        waveformSampleRate,
      ];

  @override
  MsgrAudioMessage themed(MsgrMessageTheme theme) => copyWith(theme: theme);
}

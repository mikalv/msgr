import 'package:meta/meta.dart';

import 'msgr_message.dart';
import 'msgr_theme.dart';

/// Message that shares a geographic location or map pin.
@immutable
class MsgrLocationMessage extends MsgrAuthoredMessage {
  /// Creates a location message.
  const MsgrLocationMessage({
    required super.id,
    required this.latitude,
    required this.longitude,
    this.label,
    this.zoom,
    required super.profileId,
    required super.profileName,
    required super.profileMode,
    super.status,
    super.sentAt,
    super.insertedAt,
    super.isLocal,
    super.theme,
  }) : super(kind: MsgrMessageKind.location);

  /// Latitude component of the shared location.
  final double latitude;

  /// Longitude component of the shared location.
  final double longitude;

  /// Optional label or formatted address for the coordinate.
  final String? label;

  /// Preferred map zoom level when opening the link.
  final double? zoom;

  /// Creates a copy with selectively overridden fields.
  MsgrLocationMessage copyWith({
    String? id,
    double? latitude,
    double? longitude,
    String? label,
    double? zoom,
    String? profileId,
    String? profileName,
    String? profileMode,
    String? status,
    DateTime? sentAt,
    DateTime? insertedAt,
    bool? isLocal,
    MsgrMessageTheme? theme,
  }) {
    return MsgrLocationMessage(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      label: label ?? this.label,
      zoom: zoom ?? this.zoom,
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

  /// Recreates an [MsgrLocationMessage] from a JSON compatible map.
  factory MsgrLocationMessage.fromMap(Map<String, dynamic> map) {
    final author = MsgrAuthoredMessage.readAuthorMap(map);
    return MsgrLocationMessage(
      id: map['id'] as String,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      label: map['label'] as String? ?? map['address'] as String?,
      zoom: (map['zoom'] as num?)?.toDouble(),
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
      'latitude': latitude,
      'longitude': longitude,
      'label': label,
      // Preserve legacy payloads still reading `address`.
      'address': label,
      'zoom': zoom,
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
        latitude,
        longitude,
        label,
        zoom,
      ];

  @override
  MsgrLocationMessage themed(MsgrMessageTheme theme) => copyWith(theme: theme);
}

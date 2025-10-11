import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'msgr_theme.dart';

/// Describes the type of message rendered in the chat timeline.
enum MsgrMessageKind {
  /// Standard conversational text.
  text,

  /// Markdown formatted content.
  markdown,

  /// Code snippet content with optional language metadata.
  code,

  /// System generated information.
  system,

  /// Rich media image content.
  image,

  /// Video media content.
  video,

  /// Audio media content.
  audio,

  /// Short voice note content.
  voice,

  /// Generic file attachment message.
  file,

  /// Shared location or map message.
  location,
}

/// Base class for all message variants in the chat domain.
abstract class MsgrMessage extends Equatable {
  /// Creates a new message instance.
  const MsgrMessage({
    required this.id,
    required this.kind,
    this.sentAt,
    this.insertedAt,
    this.isLocal = false,
    MsgrMessageTheme? theme,
  }) : theme = theme ?? MsgrMessageTheme.defaultTheme;

  /// Unique identifier for the message.
  final String id;

  /// Variant of the message being represented.
  final MsgrMessageKind kind;

  /// Timestamp describing when the sender triggered delivery.
  final DateTime? sentAt;

  /// Timestamp describing when the backend persisted the message.
  final DateTime? insertedAt;

  /// Whether the message only exists locally and has not been confirmed.
  final bool isLocal;

  /// Theme used to render the message bubble.
  final MsgrMessageTheme theme;

  /// Serialises the message into a JSON friendly representation.
  Map<String, dynamic> toMap();

  /// Creates a copy of the message with the provided [theme].
  MsgrMessage themed(MsgrMessageTheme theme);

  /// Attempts to parse a [DateTime] from the provided [value].
  static DateTime? parseTimestamp(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse(value.toString());
  }

  /// Formats a [DateTime] into an ISO string, returning `null` when absent.
  static String? encodeTimestamp(DateTime? value) => value?.toIso8601String();

  /// Reads the theme information from the provided payload.
  static MsgrMessageTheme readTheme(Map<String, dynamic> map) {
    final value = map['theme'];
    if (value is MsgrMessageTheme) {
      return value;
    }
    if (value is Map<String, dynamic>) {
      return MsgrMessageTheme.fromMap(value);
    }
    return MsgrMessageTheme.defaultTheme;
  }

  @override
  List<Object?> get props => [id, kind, sentAt, insertedAt, isLocal, theme];
}

/// Common base class for messages authored by a profile.
@immutable
abstract class MsgrAuthoredMessage extends MsgrMessage {
  /// Creates a new authored message instance.
  const MsgrAuthoredMessage({
    required super.id,
    required super.kind,
    required this.profileId,
    required this.profileName,
    required this.profileMode,
    this.status = 'sent',
    super.sentAt,
    super.insertedAt,
    super.isLocal,
    super.theme,
  });

  /// Identifier of the profile that authored the message.
  final String profileId;

  /// Human readable name of the author.
  final String profileName;

  /// Rendering mode of the profile (public/private/bot etc.).
  final String profileMode;

  /// Delivery status of the message. Defaults to `sent`.
  final String status;

  /// Converts shared fields into a JSON friendly representation.
  @protected
  Map<String, dynamic> toAuthorMap() {
    return {
      'profileId': profileId,
      'profileName': profileName,
      'profileMode': profileMode,
      'status': status,
    };
  }

  /// Populates [MsgrAuthoredMessage] fields from the given [map].
  @protected
  static ({
    String profileId,
    String profileName,
    String profileMode,
    String status,
    DateTime? sentAt,
    DateTime? insertedAt,
    bool isLocal,
  }) readAuthorMap(Map<String, dynamic> map) {
    return (
      profileId: map['profileId'] as String? ?? '',
      profileName: map['profileName'] as String? ?? '',
      profileMode: map['profileMode'] as String? ?? 'private',
      status: map['status'] as String? ?? 'sent',
      sentAt: MsgrMessage.parseTimestamp(map['sentAt'] ?? map['sent_at']),
      insertedAt:
          MsgrMessage.parseTimestamp(map['insertedAt'] ?? map['inserted_at']),
      isLocal: map['isLocal'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        profileId,
        profileName,
        profileMode,
        status,
      ];
}

import 'package:msgr_messages/msgr_messages.dart';

class ChatMessage {
  const ChatMessage._(
    this.message, {
    this.metadata = const <String, dynamic>{},
    this.editedAt,
    this.deletedAt,
    this.threadId,
  });

  /// Underlying domain message.
  final MsgrMessage message;

  /// Optional metadata associated with the message.
  final Map<String, dynamic> metadata;

  /// When the message was last edited.
  final DateTime? editedAt;

  /// When the message was deleted (soft delete).
  final DateTime? deletedAt;

  /// Optional thread identifier.
  final String? threadId;

  /// Creates a chat message from an existing msgr message instance.
  factory ChatMessage.fromMsgrMessage(MsgrMessage message) => ChatMessage._(message);

  /// Convenience constructor for authored text messages.
  factory ChatMessage.text({
    required String id,
    required String body,
    required String profileId,
    required String profileName,
    required String profileMode,
    required String status,
    DateTime? sentAt,
    DateTime? insertedAt,
    bool isLocal = false,
    MsgrMessageTheme? theme,
  }) {
    return ChatMessage._(
      MsgrTextMessage(
        id: id,
        body: body,
        profileId: profileId,
        profileName: profileName,
        profileMode: profileMode,
        status: status,
        sentAt: sentAt,
        insertedAt: insertedAt,
        isLocal: isLocal,
        theme: theme,
      ),
    );
  }

  /// Parses a message payload received from the backend.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>? ?? const {};
    final base = <String, dynamic>{
      'type': json['type'] as String? ?? 'text',
      'id': json['id'] as String,
      'body': json['body'],
      'profileId': profile['id'] as String? ?? '',
      'profileName': profile['name'] as String? ?? 'Ukjent',
      'profileMode': profile['mode'] as String? ?? 'private',
      'status': json['status'] as String? ?? 'sent',
      'sentAt': json['sent_at'] ?? json['sentAt'],
      'insertedAt': json['inserted_at'] ?? json['insertedAt'],
      'isLocal': json['isLocal'] as bool? ?? false,
      'theme': json['theme'],
    };

    final payload = json['payload'];
    if (payload is Map<String, dynamic>) {
      base.addAll(_normalisePayload(payload));
    }

    final message = msgrMessageFromMap(base);

    final metadata = Map<String, dynamic>.from(
      (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return ChatMessage._(
      message,
      metadata: metadata,
      editedAt: parseDate(json['edited_at'] ?? json['editedAt']),
      deletedAt: parseDate(json['deleted_at'] ?? json['deletedAt']),
      threadId: json['thread_id'] as String? ?? json['threadId'] as String?,
    );
  }

  /// Serialises the chat message into a JSON compatible structure.
  Map<String, dynamic> toJson() {
    final map = message.toMap();
    final payload = Map<String, dynamic>.from(map);

    final profile = message is MsgrAuthoredMessage
        ? {
            'id': (message as MsgrAuthoredMessage).profileId,
            'name': (message as MsgrAuthoredMessage).profileName,
            'mode': (message as MsgrAuthoredMessage).profileMode,
          }
        : null;

    final knownKeys = {
      'id',
      'type',
      'body',
      'profileId',
      'profileName',
      'profileMode',
      'status',
      'sentAt',
      'insertedAt',
      'isLocal',
      'theme',
    };

    final body = payload['body'];
    if (body == null) {
      payload.remove('body');
    }

    final json = <String, dynamic>{
      'id': payload.remove('id'),
      'type': payload.remove('type'),
      'status': payload.remove('status'),
      'sentAt': payload.remove('sentAt'),
      'insertedAt': payload.remove('insertedAt'),
      'isLocal': payload.remove('isLocal'),
      'theme': payload.remove('theme'),
      if (body != null) 'body': body,
      if (profile != null) 'profile': profile,
    };

    payload.removeWhere((key, _) => knownKeys.contains(key));

    if (payload.isNotEmpty) {
      json['payload'] = payload;
    }

    if (metadata.isNotEmpty) {
      json['metadata'] = metadata;
    }

    if (threadId != null) {
      json['threadId'] = threadId;
    }

    if (editedAt != null) {
      json['editedAt'] = editedAt!.toIso8601String();
    }

    if (deletedAt != null) {
      json['deletedAt'] = deletedAt!.toIso8601String();
    }

    json.removeWhere((_, value) => value == null);

    return json;
  }

  /// Applies a palette theme to the underlying message.
  ChatMessage applyTheme(MsgrThemePalette palette, {String? themeId}) {
    final resolved = palette.resolve(themeId ?? theme.id);
    return ChatMessage._(
      message.themed(resolved),
      metadata: metadata,
      editedAt: editedAt,
      deletedAt: deletedAt,
      threadId: threadId,
    );
  }

  /// Updates the message using a subset of common fields.
  ChatMessage copyWith({
    String? id,
    String? body,
    String? status,
    DateTime? sentAt,
    DateTime? insertedAt,
    bool? isLocal,
    MsgrMessageTheme? theme,
    Map<String, dynamic>? metadata,
    DateTime? editedAt,
    DateTime? deletedAt,
    String? threadId,
  }) {
    MsgrMessage updated;

    if (message is MsgrTextMessage) {
      updated = (message as MsgrTextMessage).copyWith(
        id: id,
        body: body,
        status: status,
        sentAt: sentAt,
        insertedAt: insertedAt,
        isLocal: isLocal,
        theme: theme,
      );
    } else if (message is MsgrMarkdownMessage) {
      updated = (message as MsgrMarkdownMessage).copyWith(
        id: id,
        markdown: body ?? (message as MsgrMarkdownMessage).markdown,
        status: status,
        sentAt: sentAt,
        insertedAt: insertedAt,
        isLocal: isLocal,
        theme: theme,
      );
    } else if (message is MsgrCodeMessage) {
      updated = (message as MsgrCodeMessage).copyWith(
        id: id,
        code: body ?? (message as MsgrCodeMessage).code,
        status: status,
        sentAt: sentAt,
        insertedAt: insertedAt,
        isLocal: isLocal,
        theme: theme,
      );
    } else if (message is MsgrImageMessage) {
      updated = (message as MsgrImageMessage).copyWith(
        id: id,
        description: body ?? (message as MsgrImageMessage).description,
        status: status,
        sentAt: sentAt,
        insertedAt: insertedAt,
        isLocal: isLocal,
        theme: theme,
      );
    } else if (message is MsgrVideoMessage) {
      updated = (message as MsgrVideoMessage).copyWith(
        id: id,
        caption: body ?? (message as MsgrVideoMessage).caption,
        status: status,
        sentAt: sentAt,
        insertedAt: insertedAt,
        isLocal: isLocal,
        theme: theme,
      );
    } else if (message is MsgrAudioMessage) {
      updated = (message as MsgrAudioMessage).copyWith(
        id: id,
        caption: body ?? (message as MsgrAudioMessage).caption,
        status: status,
        sentAt: sentAt,
        insertedAt: insertedAt,
        isLocal: isLocal,
        theme: theme,
      );
    } else if (message is MsgrLocationMessage) {
      updated = (message as MsgrLocationMessage).copyWith(
        id: id,
        label: body ?? (message as MsgrLocationMessage).label,
        status: status,
        sentAt: sentAt,
        insertedAt: insertedAt,
        isLocal: isLocal,
        theme: theme,
      );
    } else if (message is MsgrSystemMessage) {
      updated = (message as MsgrSystemMessage).copyWith(
        id: id,
        text: body ?? (message as MsgrSystemMessage).text,
        sentAt: sentAt,
        insertedAt: insertedAt,
        isLocal: isLocal,
        theme: theme,
      );
    } else {
      throw UnsupportedError('Unsupported message type: ${message.runtimeType}');
    }

    return ChatMessage._(
      updated,
      metadata: metadata ?? this.metadata,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      threadId: threadId ?? this.threadId,
    );
  }

  /// Returns the textual representation for the message when available.
  String get body {
    if (message is MsgrTextMessage) {
      return (message as MsgrTextMessage).body;
    }
    if (message is MsgrMarkdownMessage) {
      return (message as MsgrMarkdownMessage).markdown;
    }
    if (message is MsgrCodeMessage) {
      return (message as MsgrCodeMessage).code;
    }
    if (message is MsgrAudioMessage) {
      return (message as MsgrAudioMessage).caption ?? '';
    }
    if (message is MsgrVideoMessage) {
      return (message as MsgrVideoMessage).caption ?? '';
    }
    if (message is MsgrImageMessage) {
      return (message as MsgrImageMessage).description ?? '';
    }
    if (message is MsgrLocationMessage) {
      return (message as MsgrLocationMessage).label ?? '';
    }
    if (message is MsgrSystemMessage) {
      return (message as MsgrSystemMessage).text;
    }
    return '';
  }

  /// Identifier of the underlying message.
  String get id => message.id;

  /// Message kind (text, audio, video, etc.).
  MsgrMessageKind get kind => message.kind;

  /// Author profile identifier when present.
  String get profileId =>
      message is MsgrAuthoredMessage ? (message as MsgrAuthoredMessage).profileId : '';

  /// Author display name when present.
  String get profileName =>
      message is MsgrAuthoredMessage ? (message as MsgrAuthoredMessage).profileName : '';

  /// Author rendering mode when present.
  String get profileMode =>
      message is MsgrAuthoredMessage ? (message as MsgrAuthoredMessage).profileMode : 'system';

  /// Delivery status for authored messages.
  String get status =>
      message is MsgrAuthoredMessage ? (message as MsgrAuthoredMessage).status : 'sent';

  /// Indicates whether the message has been edited since creation.
  bool get isEdited => editedAt != null;

  /// Indicates whether the message has been soft deleted.
  bool get isDeleted => deletedAt != null;

  /// When the message was sent by the client.
  DateTime? get sentAt => message.sentAt;

  /// When the message was persisted by the backend.
  DateTime? get insertedAt => message.insertedAt;

  /// Whether the message is only present locally.
  bool get isLocal => message.isLocal;

  /// Active theme for rendering.
  MsgrMessageTheme get theme => message.theme;
}

Map<String, dynamic> _normalisePayload(Map<String, dynamic> payload) {
  final flattened = Map<String, dynamic>.from(payload);
  final media = payload['media'];

  if (media is Map<String, dynamic>) {
    final url = media['url'];
    if (url is String) {
      flattened['url'] = url;
    }

    final contentType = media['contentType'] ?? media['mimeType'];
    if (contentType is String) {
      flattened['mimeType'] = contentType;
      flattened['contentType'] = contentType;
    }

    final caption = media['caption'];
    if (caption is String) {
      flattened['caption'] = caption;
    }

    final duration = media['duration'];
    if (duration is num) {
      flattened['duration'] = duration.toDouble();
    } else {
      final durationMs = media['durationMs'];
      if (durationMs is num) {
        flattened['duration'] = durationMs.toDouble() / 1000;
      }
    }

    final waveform = media['waveform'];
    if (waveform is List) {
      flattened['waveform'] = waveform;
    }
  }

  return flattened;
}

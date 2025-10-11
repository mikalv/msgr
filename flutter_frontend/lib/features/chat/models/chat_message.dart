import 'package:msgr_messages/msgr_messages.dart';

class ChatMessage {
  const ChatMessage._(this.message);

  /// Underlying domain message.
  final MsgrMessage message;

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
    return ChatMessage._(message);
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

    json.removeWhere((_, value) => value == null);

    return json;
  }

  /// Applies a palette theme to the underlying message.
  ChatMessage applyTheme(MsgrThemePalette palette, {String? themeId}) {
    final resolved = palette.resolve(themeId ?? theme.id);
    return ChatMessage._(message.themed(resolved));
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

    return ChatMessage._(updated);
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
    if (message is MsgrFileMessage) {
      return (message as MsgrFileMessage).caption ?? '';
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

    final checksum = media['checksum'];
    if (checksum is String) {
      flattened['checksum'] = checksum;
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

    final waveformSampleRate = media['waveformSampleRate'];
    if (waveformSampleRate is num) {
      flattened['waveformSampleRate'] = waveformSampleRate.toInt();
    }

    final width = media['width'];
    if (width is num) {
      flattened['width'] = width.toInt();
    }

    final height = media['height'];
    if (height is num) {
      flattened['height'] = height.toInt();
    }

    final metadata = media['metadata'];
    if (metadata is Map) {
      final safeMetadata = Map<String, dynamic>.from(metadata);
      flattened['metadata'] = safeMetadata;
      final fileName = safeMetadata['fileName'];
      if (fileName is String) {
        flattened['fileName'] = fileName;
      }
    }

    final thumbnail = media['thumbnail'];
    if (thumbnail is Map) {
      final thumbUrl = thumbnail['url'] ?? thumbnail['publicUrl'];
      if (thumbUrl is String) {
        flattened['thumbnailUrl'] = thumbUrl;
      }

      final thumbWidth = thumbnail['width'];
      if (thumbWidth is num) {
        flattened['thumbnailWidth'] = thumbWidth.toInt();
      }

      final thumbHeight = thumbnail['height'];
      if (thumbHeight is num) {
        flattened['thumbnailHeight'] = thumbHeight.toInt();
      }
    }
  }

  return flattened;
}

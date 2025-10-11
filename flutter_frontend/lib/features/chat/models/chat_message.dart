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

    final payload = <String, dynamic>{};
    final jsonPayload = json['payload'];
    if (jsonPayload is Map<String, dynamic>) {
      payload.addAll(jsonPayload);
    }

    final topLevelMedia = json['media'];
    if (topLevelMedia is Map<String, dynamic>) {
      final merged = Map<String, dynamic>.from(
        payload['media'] as Map<String, dynamic>? ?? const {},
      );
      merged.addAll(topLevelMedia);
      payload['media'] = merged;
    }

    if (payload.isNotEmpty) {
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
        kind: (message as MsgrAudioMessage).kind,
      );
    } else if (message is MsgrFileMessage) {
      updated = (message as MsgrFileMessage).copyWith(
        id: id,
        caption: body ?? (message as MsgrFileMessage).caption,
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
    if (message is MsgrFileMessage) {
      return (message as MsgrFileMessage).caption ??
          (message as MsgrFileMessage).fileName;
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

  /// When the message was sent by the client.
  DateTime? get sentAt => message.sentAt;

  /// When the message was persisted by the backend.
  DateTime? get insertedAt => message.insertedAt;

  /// Whether the message is only present locally.
  bool get isLocal => message.isLocal;

  /// Active theme for rendering.
  MsgrMessageTheme get theme => message.theme;

  /// Exposes the underlying message instance for advanced rendering.
  MsgrMessage get data => message;
}

Map<String, dynamic> _normalisePayload(Map<String, dynamic> payload) {
  final flattened = <String, dynamic>{};

  for (final entry in payload.entries) {
    if (entry.key != 'media') {
      flattened[entry.key] = entry.value;
    }
  }

  final media = payload['media'];
  if (media is Map<String, dynamic>) {
    final normalizedMedia = <String, dynamic>{};

    void putString(String targetKey, dynamic value) {
      if (value is String && value.isNotEmpty) {
        normalizedMedia[targetKey] = value;
      }
    }

    void putInt(String targetKey, dynamic value) {
      final parsed = _parseInt(value);
      if (parsed != null) {
        normalizedMedia[targetKey] = parsed;
      }
    }

    putString('url', media['url'] ?? media['publicUrl']);
    putString('bucket', media['bucket']);
    putString('objectKey', media['objectKey'] ?? media['object_key']);
    final contentType = media['contentType'] ?? media['mimeType'];
    putString('contentType', contentType);
    if (contentType is String) {
      normalizedMedia['mimeType'] = contentType;
    }
    putString('caption', media['caption'] ?? media['description']);
    putString('fileName', media['fileName'] ?? media['name']);
    putInt('byteSize', media['byteSize'] ?? media['size']);
    putInt('width', media['width']);
    putInt('height', media['height']);
    putString('sha256', media['sha256'] ?? media['hash']);

    final retention = media['retentionExpiresAt'] ?? media['retention_expires_at'];
    if (retention is String) {
      normalizedMedia['retentionExpiresAt'] = retention;
    }

    final duration = media['duration'];
    if (duration is num) {
      normalizedMedia['duration'] = duration.toDouble();
    } else {
      final durationMs = media['durationMs'];
      if (durationMs is num) {
        normalizedMedia['duration'] = durationMs.toDouble() / 1000;
        normalizedMedia['durationMs'] = durationMs.toInt();
      }
    }

    final waveform = media['waveform'] ?? media['waveForm'];
    if (waveform is List) {
      final samples = waveform
          .whereType<num>()
          .map((value) => value.toDouble())
          .map((value) => value.clamp(0, 100).toDouble())
          .toList(growable: false);
      if (samples.isNotEmpty) {
        normalizedMedia['waveform'] = samples;
      }
    }

    final rawThumbnail = media['thumbnail'] ?? media['thumbnailUrl'];
    if (rawThumbnail is Map<String, dynamic>) {
      final thumbnail = <String, dynamic>{};
      final thumbUrl = rawThumbnail['url'] ?? rawThumbnail['publicUrl'];
      if (thumbUrl is String && thumbUrl.isNotEmpty) {
        normalizedMedia['thumbnailUrl'] = thumbUrl;
        thumbnail['url'] = thumbUrl;
      }
      final thumbWidth = _parseInt(rawThumbnail['width']);
      if (thumbWidth != null) {
        normalizedMedia['thumbnailWidth'] = thumbWidth;
        thumbnail['width'] = thumbWidth;
      }
      final thumbHeight = _parseInt(rawThumbnail['height']);
      if (thumbHeight != null) {
        normalizedMedia['thumbnailHeight'] = thumbHeight;
        thumbnail['height'] = thumbHeight;
      }
      final thumbContentType = rawThumbnail['contentType'] ?? rawThumbnail['content_type'];
      if (thumbContentType is String && thumbContentType.isNotEmpty) {
        normalizedMedia['thumbnailContentType'] = thumbContentType;
        thumbnail['contentType'] = thumbContentType;
      }
      final thumbObjectKey = rawThumbnail['objectKey'] ?? rawThumbnail['object_key'];
      if (thumbObjectKey is String && thumbObjectKey.isNotEmpty) {
        normalizedMedia['thumbnailObjectKey'] = thumbObjectKey;
        thumbnail['objectKey'] = thumbObjectKey;
      }
      final thumbBucket = rawThumbnail['bucket'];
      if (thumbBucket is String && thumbBucket.isNotEmpty) {
        normalizedMedia['thumbnailBucket'] = thumbBucket;
        thumbnail['bucket'] = thumbBucket;
      }
      if (thumbnail.isNotEmpty) {
        normalizedMedia['thumbnail'] = thumbnail;
      }
    } else if (rawThumbnail is String && rawThumbnail.isNotEmpty) {
      normalizedMedia['thumbnailUrl'] = rawThumbnail;
    }

    flattened.addAll(normalizedMedia);
    flattened['media'] = normalizedMedia;
  }

  return flattened;
}

int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }
  return null;
}

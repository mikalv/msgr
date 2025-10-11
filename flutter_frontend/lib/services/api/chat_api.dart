import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/features/chat/models/chat_message.dart';
import 'package:messngr/features/chat/models/chat_thread.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException(statusCode: $statusCode, body: $body)';
}

class AccountIdentity {
  const AccountIdentity({required this.accountId, required this.profileId});

  final String accountId;
  final String profileId;
}

class ThumbnailUploadInfo {
  const ThumbnailUploadInfo({
    required this.method,
    required this.url,
    required this.headers,
    required this.bucket,
    required this.objectKey,
    required this.publicUrl,
    required this.expiresAt,
  });

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String bucket;
  final String objectKey;
  final Uri publicUrl;
  final DateTime expiresAt;

  factory ThumbnailUploadInfo.fromJson(Map<String, dynamic> json) {
    return ThumbnailUploadInfo(
      method: json['method'] as String? ?? 'PUT',
      url: Uri.parse(json['url'] as String? ?? ''),
      headers: _stringMap(json['headers'] as Map<String, dynamic>? ?? const {}),
      bucket: json['bucket'] as String? ?? '',
      objectKey: json['object_key'] as String? ?? json['objectKey'] as String? ?? '',
      publicUrl: Uri.parse(json['public_url'] as String? ?? json['publicUrl'] as String? ?? ''),
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? json['expiresAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class PresignedUploadInfo {
  const PresignedUploadInfo({
    required this.method,
    required this.url,
    required this.headers,
    required this.bucket,
    required this.objectKey,
    required this.publicUrl,
    required this.expiresAt,
    this.retentionExpiresAt,
    this.thumbnail,
  });

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String bucket;
  final String objectKey;
  final Uri publicUrl;
  final DateTime expiresAt;
  final DateTime? retentionExpiresAt;
  final ThumbnailUploadInfo? thumbnail;

  factory PresignedUploadInfo.fromJson(Map<String, dynamic> json) {
    final thumbnail = json['thumbnail_upload'] ?? json['thumbnailUpload'];
    return PresignedUploadInfo(
      method: json['method'] as String? ?? 'PUT',
      url: Uri.parse(json['url'] as String? ?? ''),
      headers: _stringMap(json['headers'] as Map<String, dynamic>? ?? const {}),
      bucket: json['bucket'] as String? ?? '',
      objectKey: json['object_key'] as String? ?? json['objectKey'] as String? ?? '',
      publicUrl: Uri.parse(json['public_url'] as String? ?? json['publicUrl'] as String? ?? ''),
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? json['expiresAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      retentionExpiresAt: DateTime.tryParse(json['retention_expires_at'] as String? ?? json['retentionExpiresAt'] as String? ?? ''),
      thumbnail: thumbnail is Map<String, dynamic> ? ThumbnailUploadInfo.fromJson(thumbnail) : null,
    );
  }
}

class MediaUploadSession {
  const MediaUploadSession({
    required this.id,
    required this.kind,
    required this.contentType,
    required this.byteSize,
    required this.instructions,
  });

  final String id;
  final String kind;
  final String contentType;
  final int byteSize;
  final PresignedUploadInfo instructions;

  factory MediaUploadSession.fromJson(Map<String, dynamic> json) {
    final upload = json['upload'] as Map<String, dynamic>? ?? const {};
    return MediaUploadSession(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? 'file',
      contentType: json['content_type'] as String? ?? json['contentType'] as String? ?? 'application/octet-stream',
      byteSize: (json['byte_size'] as num?)?.toInt() ?? 0,
      instructions: PresignedUploadInfo.fromJson(upload),
    );
  }
class MediaUploadRequest {
  const MediaUploadRequest({
    required this.kind,
    required this.contentType,
    required this.byteSize,
    this.fileName,
  });

  final String kind;
  final String contentType;
  final int byteSize;
  final String? fileName;
}

class MediaUploadInstructions {
  const MediaUploadInstructions({
    required this.id,
    required this.bucket,
    required this.objectKey,
    required this.uploadMethod,
    required this.uploadUrl,
    required this.uploadHeaders,
    required this.downloadMethod,
    required this.downloadUrl,
    this.uploadExpiresAt,
    this.downloadExpiresAt,
    this.publicUrl,
    this.retentionUntil,
  });

  final String id;
  final String bucket;
  final String objectKey;
  final String uploadMethod;
  final Uri uploadUrl;
  final Map<String, String> uploadHeaders;
  final String downloadMethod;
  final Uri downloadUrl;
  final DateTime? uploadExpiresAt;
  final DateTime? downloadExpiresAt;
  final Uri? publicUrl;
  final DateTime? retentionUntil;
}

class ChatApi {
  ChatApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AccountIdentity> createAccount(String displayName, {String? email}) async {
    final response = await _client.post(
      backendApiUri('users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'display_name': displayName,
        if (email != null) 'email': email,
      }),
    );

    final decoded = _decodeBody(response);
    final data = decoded['data'] as Map<String, dynamic>;
    final profiles = data['profiles'] as List<dynamic>? ?? const [];
    final profile = profiles.isEmpty ? null : profiles.first as Map<String, dynamic>;

    if (profile == null) {
      throw ApiException(response.statusCode, response.body);
    }

    return AccountIdentity(
      accountId: data['id'] as String,
      profileId: profile['id'] as String,
    );
  }

  Future<ChatThread> ensureDirectConversation({
    required AccountIdentity current,
    required String targetProfileId,
  }) async {
    final response = await _client.post(
      backendApiUri('conversations'),
      headers: _authHeaders(current),
      body: jsonEncode({'target_profile_id': targetProfileId}),
    );

    final decoded = _decodeBody(response);
    final data = decoded['data'] as Map<String, dynamic>;
    return ChatThread.fromJson(data);
  }

  Future<List<ChatThread>> listConversations({
    required AccountIdentity current,
  }) async {
    final response = await _client.get(
      backendApiUri('conversations'),
      headers: _authHeaders(current),
    );

    final decoded = _decodeBody(response);
    final data = decoded['data'] as List<dynamic>? ?? const [];
    return data
        .map((raw) => ChatThread.fromJson(raw as Map<String, dynamic>))
        .toList();
  }

  Future<ChatThread> createGroupConversation({
    required AccountIdentity current,
    required String topic,
    required List<String> participantIds,
    ChatStructureType structureType = ChatStructureType.friends,
  }) async {
    final response = await _client.post(
      backendApiUri('conversations'),
      headers: _authHeaders(current),
      body: jsonEncode({
        'kind': 'group',
        'topic': topic,
        'participant_ids': participantIds,
        'structure_type': _structureTypeToJson(structureType),
      }),
    );

    final decoded = _decodeBody(response);
    final data = decoded['data'] as Map<String, dynamic>;
    return ChatThread.fromJson(data);
  }

  Future<ChatThread> createChannelConversation({
    required AccountIdentity current,
    required String topic,
    List<String> participantIds = const [],
    ChatStructureType structureType = ChatStructureType.project,
    ChatVisibility visibility = ChatVisibility.team,
  }) async {
    final response = await _client.post(
      backendApiUri('conversations'),
      headers: _authHeaders(current),
      body: jsonEncode({
        'kind': 'channel',
        'topic': topic,
        'participant_ids': participantIds,
        'structure_type': _structureTypeToJson(structureType),
        'visibility': _visibilityToJson(visibility),
      }),
    );

    final decoded = _decodeBody(response);
    final data = decoded['data'] as Map<String, dynamic>;
    return ChatThread.fromJson(data);
  }

  Future<MediaUploadInstructions> createMediaUpload({
    required AccountIdentity current,
    required String conversationId,
    required MediaUploadRequest request,
  }) async {
    final response = await _client.post(
      backendApiUri('conversations/$conversationId/uploads'),
      headers: _authHeaders(current),
      body: jsonEncode({
        'upload': {
          'kind': request.kind,
          'content_type': request.contentType,
          'byte_size': request.byteSize,
          if (request.fileName != null) 'filename': request.fileName,
        },
      }),
    );

    final decoded = _decodeBody(response);
    final data = decoded['data'] as Map<String, dynamic>;
    final upload = data['upload'] as Map<String, dynamic>;
    final download = data['download'] as Map<String, dynamic>;

    return MediaUploadInstructions(
      id: data['id'] as String,
      bucket: data['bucket'] as String,
      objectKey: data['object_key'] as String,
      uploadMethod: upload['method'] as String,
      uploadUrl: Uri.parse(upload['url'] as String),
      uploadHeaders: _stringHeaders(upload['headers'] as Map),
      uploadExpiresAt: _parseDate(upload['expires_at']),
      downloadMethod: download['method'] as String,
      downloadUrl: Uri.parse(download['url'] as String),
      downloadExpiresAt: _parseDate(download['expires_at']),
      publicUrl:
          data['public_url'] != null ? Uri.parse(data['public_url'] as String) : null,
      retentionUntil: _parseDate(data['retention_until']),
    );
  }

  Future<List<ChatMessage>> fetchMessages({
    required AccountIdentity current,
    required String conversationId,
    int limit = 50,
  }) async {
    final uri = backendApiUri(
      'conversations/$conversationId/messages',
      queryParameters: {'limit': '$limit'},
    );

    final response = await _client.get(uri, headers: _authHeaders(current));

    final decoded = _decodeBody(response);
    final data = decoded['data'] as List<dynamic>;
    return data.map((raw) => ChatMessage.fromJson(raw as Map<String, dynamic>)).toList();
  }

  Future<ChatMessage> sendStructuredMessage({
    required AccountIdentity current,
    required String conversationId,
    String? body,
    String? kind,
    Map<String, dynamic>? media,
    Map<String, dynamic>? payload,
  }) async {
    final decoded = await sendStructuredMessage(
      current: current,
      conversationId: conversationId,
      message: {'body': body},
    );
    return decoded;
  }

  Future<ChatMessage> sendStructuredMessage({
    required AccountIdentity current,
    required String conversationId,
    required Map<String, dynamic> message,
  }) async {
    final message = <String, dynamic>{};
    if (body != null) message['body'] = body;
    if (kind != null) message['kind'] = kind;
    if (media != null && media.isNotEmpty) message['media'] = media;
    if (payload != null && payload.isNotEmpty) message['payload'] = payload;

    if (message.isEmpty) {
      throw ArgumentError('message payload cannot be empty');
    }

    final response = await _client.post(
      backendApiUri('conversations/$conversationId/messages'),
      headers: _authHeaders(current),
      body: jsonEncode({'message': message}),
    );

    final decoded = _decodeBody(response);
    return ChatMessage.fromJson(decoded['data'] as Map<String, dynamic>);
  }

  Future<MediaUploadSession> createMediaUpload({
    required AccountIdentity current,
    required String conversationId,
    required String kind,
    required String contentType,
    required int byteSize,
    String? filename,
  }) async {
    final response = await _client.post(
      backendApiUri('conversations/$conversationId/uploads'),
      headers: _authHeaders(current),
      body: jsonEncode({
        'upload': {
          'kind': kind,
          'content_type': contentType,
          'byte_size': byteSize,
          if (filename != null) 'filename': filename,
        }
      }),
    );

    final decoded = _decodeBody(response);
    final data = decoded['data'] as Map<String, dynamic>;
    return MediaUploadSession.fromJson(data);
  }

  Map<String, String> _authHeaders(AccountIdentity identity) {
    return {
      'Content-Type': 'application/json',
      'x-account-id': identity.accountId,
      'x-profile-id': identity.profileId,
    };
  }

  String _structureTypeToJson(ChatStructureType type) {
    switch (type) {
      case ChatStructureType.family:
        return 'family';
      case ChatStructureType.business:
        return 'business';
      case ChatStructureType.friends:
        return 'friends';
      case ChatStructureType.project:
        return 'project';
      case ChatStructureType.other:
        return 'other';
    }
  }

  String _visibilityToJson(ChatVisibility visibility) {
    switch (visibility) {
      case ChatVisibility.private:
        return 'private';
      case ChatVisibility.team:
        return 'team';
    }
  }

  Map<String, String> _stringHeaders(Map<dynamic, dynamic> headers) {
    return headers.map((key, value) => MapEntry(key.toString(), value.toString()));
  }

  DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    final body = response.body.isEmpty ? '{}' : response.body;
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    throw ApiException(response.statusCode, response.body);
  }

  static Map<String, String> _stringMap(Map<String, dynamic> input) {
    return input.map((key, value) => MapEntry(key.toString(), value == null ? '' : value.toString()));
  }
}

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
}

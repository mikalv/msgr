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

  Future<ChatMessage> sendMessage({
    required AccountIdentity current,
    required String conversationId,
    required String body,
  }) async {
    final response = await _client.post(
      backendApiUri('conversations/$conversationId/messages'),
      headers: _authHeaders(current),
      body: jsonEncode({
        'message': {'body': body},
      }),
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

  Map<String, dynamic> _decodeBody(http.Response response) {
    final body = response.body.isEmpty ? '{}' : response.body;
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    throw ApiException(response.statusCode, response.body);
  }
}

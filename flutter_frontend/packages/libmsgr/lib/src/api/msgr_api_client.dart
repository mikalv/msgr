import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Pure Dart HTTP API client for Msgr.
///
/// No Flutter dependencies -- works in CLI, bot, TUI clients.
class MsgrApiClient {
  MsgrApiClient({
    required this.baseUrl,
    this.accountId,
    this.profileId,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  String? accountId;
  String? profileId;
  final http.Client _http;

  /// JWT access token (preferred over X-header auth when set).
  String? accessToken;

  /// JWT refresh token for obtaining new access tokens.
  String? refreshToken;

  /// Whether a token refresh is currently in progress.
  bool _isRefreshing = false;

  /// Callback invoked when tokens are refreshed (e.g. to persist them).
  void Function(String accessToken, String? refreshToken)? onTokensRefreshed;

  /// Callback invoked when refresh fails (tokens expired) -- triggers logout.
  void Function()? onAuthFailure;

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    } else {
      // Fall back to X-header auth
      if (accountId != null) {
        headers['X-Account-Id'] = accountId!;
      }
      if (profileId != null) {
        headers['X-Profile-Id'] = profileId!;
      }
    }
    return headers;
  }

  Uri _uri(String path, {Map<String, String>? query}) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  dynamic _handleResponseRaw(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return <String, dynamic>{};
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return <String, dynamic>{};
      }
    }
    throw MsgrApiException(
      statusCode: response.statusCode,
      message: response.body,
    );
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return <String, dynamic>{};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
        return {'data': decoded};
      } catch (_) {
        return <String, dynamic>{};
      }
    }
    throw MsgrApiException(
      statusCode: response.statusCode,
      message: response.body,
    );
  }

  // ---------------------------------------------------------------------------
  // Token refresh
  // ---------------------------------------------------------------------------

  /// Refresh the access token using the stored refresh token.
  ///
  /// Returns `true` if the token was refreshed successfully.
  Future<bool> refreshAuth() async {
    if (refreshToken == null || _isRefreshing) return false;

    _isRefreshing = true;
    try {
      final response = await _http.post(
        _uri('/api/v1/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccessToken = data['access_token'] as String?;
        if (newAccessToken != null) {
          accessToken = newAccessToken;
          onTokensRefreshed?.call(newAccessToken, refreshToken);
          return true;
        }
      }

      // Refresh failed -- tokens are invalid
      accessToken = null;
      refreshToken = null;
      onAuthFailure?.call();
      return false;
    } catch (_) {
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Execute an HTTP request with automatic 401 retry via token refresh.
  Future<http.Response> _requestWithRetry(
    Future<http.Response> Function() request,
  ) async {
    final response = await request();

    // If 401 and we have a refresh token, try refreshing and retry once
    if (response.statusCode == 401 && accessToken != null && refreshToken != null) {
      final refreshed = await refreshAuth();
      if (refreshed) {
        return request();
      }
    }

    return response;
  }

  // ---------------------------------------------------------------------------
  // Low-level HTTP verbs
  // ---------------------------------------------------------------------------

  Future<dynamic> getRaw(String path, {Map<String, String>? query}) async {
    final response = await _requestWithRetry(
      () => _http.get(_uri(path, query: query), headers: _headers()),
    );
    return _handleResponseRaw(response);
  }

  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? query}) async {
    final response = await _requestWithRetry(
      () => _http.get(_uri(path, query: query), headers: _headers()),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String path,
      {Map<String, dynamic>? body}) async {
    final response = await _requestWithRetry(
      () => _http.post(
        _uri(path),
        headers: _headers(),
        body: body != null ? jsonEncode(body) : null,
      ),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(String path,
      {Map<String, dynamic>? body}) async {
    final response = await _requestWithRetry(
      () => _http.put(
        _uri(path),
        headers: _headers(),
        body: body != null ? jsonEncode(body) : null,
      ),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> patch(String path,
      {Map<String, dynamic>? body}) async {
    final response = await _requestWithRetry(
      () => _http.patch(
        _uri(path),
        headers: _headers(),
        body: body != null ? jsonEncode(body) : null,
      ),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final response = await _requestWithRetry(
      () => _http.delete(_uri(path), headers: _headers()),
    );
    return _handleResponse(response);
  }

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  /// Request an OTP challenge.
  ///
  /// POST /api/v1/auth/challenge
  Future<ChallengeResult> requestChallenge(
    String identifier, {
    String channel = 'email',
  }) async {
    final response = await _http.post(
      _uri('/api/v1/auth/challenge'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'channel': channel, 'identifier': identifier}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MsgrApiException(
        statusCode: response.statusCode,
        message: 'Challenge request failed: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const MsgrApiException(
        statusCode: 500,
        message: 'No challenge ID in response',
      );
    }

    return ChallengeResult(
      id: id,
      channel: data['channel'] as String?,
      debugCode: data['debug_code'] as String?,
      targetHint: data['target_hint'] as String?,
    );
  }

  /// Verify an OTP code and obtain a session.
  ///
  /// POST /api/v1/auth/verify
  Future<SessionResult> verifyCode(String challengeId, String code) async {
    final response = await _http.post(
      _uri('/api/v1/auth/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'challenge_id': challengeId, 'code': code}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MsgrApiException(
        statusCode: response.statusCode,
        message: 'Verify failed: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final account = data['account'] as Map<String, dynamic>? ?? {};
    final accountIdValue = account['id'] as String? ?? '';
    if (accountIdValue.isEmpty) {
      throw const MsgrApiException(
        statusCode: 500,
        message: 'No account ID in verify response',
      );
    }

    var profileIdValue = data['profile_id'] as String? ?? '';
    if (profileIdValue.isEmpty) {
      final profiles = account['profiles'] as List? ?? [];
      if (profiles.isNotEmpty) {
        final firstProfile = profiles.first as Map<String, dynamic>;
        profileIdValue = firstProfile['id'] as String? ?? '';
      }
    }
    if (profileIdValue.isEmpty) {
      throw const MsgrApiException(
        statusCode: 500,
        message: 'No profile ID in verify response',
      );
    }

    final profiles = (account['profiles'] as List?)
        ?.map((p) => p as Map<String, dynamic>)
        .toList();

    // Extract display name: try account level first, then first profile, then
    // top-level response (some backend versions put it there).
    String? displayNameValue = account['display_name'] as String?;
    if ((displayNameValue == null || displayNameValue.isEmpty) &&
        profiles != null &&
        profiles.isNotEmpty) {
      displayNameValue = profiles.first['display_name'] as String? ??
          profiles.first['name'] as String?;
    }
    if (displayNameValue == null || displayNameValue.isEmpty) {
      displayNameValue = data['display_name'] as String?;
    }

    // Extract JWT tokens if present
    final accessTokenValue = data['access_token'] as String?;
    final refreshTokenValue = data['refresh_token'] as String?;

    // Auto-set tokens on this client when received
    if (accessTokenValue != null) {
      accessToken = accessTokenValue;
      refreshToken = refreshTokenValue;
    }

    return SessionResult(
      accountId: accountIdValue,
      profileId: profileIdValue,
      email: account['email'] as String?,
      displayName: displayNameValue,
      profiles: profiles,
      accessToken: accessTokenValue,
      refreshToken: refreshTokenValue,
    );
  }

  // ---------------------------------------------------------------------------
  // Account Settings
  // ---------------------------------------------------------------------------

  /// GET /api/settings — fetch the current account's synced preferences.
  Future<Map<String, dynamic>> getSettings() async {
    return get('/api/settings');
  }

  /// PUT /api/settings — update the current account's synced preferences.
  Future<Map<String, dynamic>> updateSettings(
      Map<String, dynamic> settings) async {
    return put('/api/settings', body: settings);
  }

  // ---------------------------------------------------------------------------
  // Teams
  // ---------------------------------------------------------------------------

  /// GET /api/teams
  Future<List<Map<String, dynamic>>> getTeams() async {
    final raw = await getRaw('/api/teams');
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
      return [raw];
    }
    return [];
  }

  /// POST /api/teams
  Future<Map<String, dynamic>> createTeam(String name, String slug,
      {String? description}) async {
    return post('/api/teams', body: {
      'name': name,
      'slug': slug,
      if (description != null) 'description': description,
    });
  }

  /// POST /api/teams/:slug/join
  Future<Map<String, dynamic>> joinTeam(String slug) async {
    return post('/api/teams/$slug/join');
  }

  // ---------------------------------------------------------------------------
  // Invite Links
  // ---------------------------------------------------------------------------

  /// POST /api/teams/:slug/invites — generate a new invite link
  Future<Map<String, dynamic>> createInviteLink(String teamSlug) async {
    return post('/api/teams/$teamSlug/invites');
  }

  /// POST /api/invite/:code — redeem an invite code
  Future<Map<String, dynamic>> redeemInvite(String code) async {
    return post('/api/invite/$code');
  }

  /// PUT /api/account/me — update current account profile
  Future<Map<String, dynamic>> updateAccount({
    String? displayName,
    String? handle,
  }) async {
    return put('/api/account/me', body: {
      if (displayName != null) 'display_name': displayName,
      if (handle != null) 'handle': handle,
    });
  }

  // ---------------------------------------------------------------------------
  // Channels
  // ---------------------------------------------------------------------------

  /// GET /api/teams/:slug/channels
  Future<List<Map<String, dynamic>>> getChannels(String teamSlug) async {
    final raw = await getRaw('/api/teams/$teamSlug/channels');
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// POST /api/teams/:slug/channels
  Future<Map<String, dynamic>> createChannel(
    String teamSlug, {
    required String name,
    String? slug,
    String? icon,
    String visibility = 'public',
    List<String>? memberIds,
  }) async {
    final channelSlug = slug ??
        name
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-|-$'), '');
    return post('/api/teams/$teamSlug/channels', body: {
      'name': name,
      'slug': channelSlug,
      'visibility': visibility,
      if (icon != null) 'icon': icon,
      if (memberIds != null && memberIds.isNotEmpty) 'member_ids': memberIds,
    });
  }

  /// POST /api/teams/:slug/channels/:channelId/members
  Future<Map<String, dynamic>> addChannelMembers(
    String teamSlug,
    String channelId,
    List<String> profileIds,
  ) async {
    return post('/api/teams/$teamSlug/channels/$channelId/members', body: {
      'profile_ids': profileIds,
    });
  }

  /// GET /api/teams/:slug/channels/:id/members — list channel members
  Future<List<Map<String, dynamic>>> getChannelMembers(
    String teamSlug,
    String channelId,
  ) async {
    final raw = await getRaw('/api/teams/$teamSlug/channels/$channelId/members');
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// DELETE /api/teams/:slug/channels/:id/members/:profile_id — remove member
  Future<void> removeChannelMember(
    String teamSlug,
    String channelId,
    String profileId,
  ) async {
    await delete('/api/teams/$teamSlug/channels/$channelId/members/$profileId');
  }

  // ---------------------------------------------------------------------------
  // Webhooks
  // ---------------------------------------------------------------------------

  /// POST /api/teams/:slug/webhooks — create incoming webhook
  Future<Map<String, dynamic>> createWebhook(
    String teamSlug, {
    required String channelId,
    required String name,
    String? avatarUrl,
  }) async {
    return post('/api/teams/$teamSlug/webhooks', body: {
      'channel_id': channelId,
      'name': name,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    });
  }

  /// GET /api/teams/:slug/webhooks — list webhooks
  Future<List<Map<String, dynamic>>> getWebhooks(String teamSlug) async {
    final raw = await getRaw('/api/teams/$teamSlug/webhooks');
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// DELETE /api/teams/:slug/webhooks/:id — delete webhook
  Future<void> deleteWebhook(String teamSlug, String id) async {
    await delete('/api/teams/$teamSlug/webhooks/$id');
  }

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  /// GET /api/teams/:slug/channels/:id/messages
  Future<List<Map<String, dynamic>>> getMessages(
    String teamSlug,
    String channelId, {
    int limit = 50,
    String? before,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (before != null) query['before'] = before;
    final raw = await getRaw(
      '/api/teams/$teamSlug/channels/$channelId/messages',
      query: query,
    );
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// POST /api/teams/:slug/channels/:id/messages
  Future<Map<String, dynamic>> sendMessage(
    String teamSlug,
    String channelId,
    String content, {
    List<String>? mediaRefs,
  }) async {
    return post('/api/teams/$teamSlug/channels/$channelId/messages', body: {
      'content': {'text': content},
      if (mediaRefs != null && mediaRefs.isNotEmpty) 'media_refs': mediaRefs,
    });
  }

  /// POST /api/teams/:slug/channels/:id/messages with rich content (JSONB).
  ///
  /// [content] can be a plain String or a Map with 'text' and optional
  /// 'mentions' list for structured content.
  Future<Map<String, dynamic>> sendMessageRich(
    String teamSlug,
    String channelId,
    dynamic content, {
    List<String>? mediaRefs,
  }) async {
    final contentValue = content is String ? {'text': content} : content;
    return post('/api/teams/$teamSlug/channels/$channelId/messages', body: {
      'content': contentValue,
      if (mediaRefs != null && mediaRefs.isNotEmpty) 'media_refs': mediaRefs,
    });
  }

  /// GET /api/teams/:slug/unread_counts
  Future<Map<String, int>> getUnreadCounts(String teamSlug) async {
    final raw = await get('/api/teams/$teamSlug/unread_counts');
    final data = raw['data'] as Map<String, dynamic>? ?? {};
    return data.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  /// PUT /api/teams/:slug/channels/:channelId/read_cursor
  Future<void> markChannelRead(String teamSlug, String channelId, String lastMessageId) async {
    await put('/api/teams/$teamSlug/channels/$channelId/read_cursor', body: {
      'last_read_message_id': lastMessageId,
    });
  }

  /// GET /api/teams/:slug/search?q=query
  Future<List<Map<String, dynamic>>> searchMessages(
    String teamSlug,
    String query, {
    String? channelId,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'q': query,
      'limit': limit.toString(),
      if (channelId != null) 'channel_id': channelId,
    };
    final raw = await get('/api/teams/$teamSlug/search', query: params);
    final data = raw['data'];
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// PATCH /api/teams/:slug/channels/:channelId/messages/:messageId
  Future<Map<String, dynamic>> editMessage(
    String teamSlug,
    String channelId,
    String messageId,
    String newText,
  ) async {
    return patch('/api/teams/$teamSlug/channels/$channelId/messages/$messageId', body: {
      'content': {'text': newText},
    });
  }

  /// DELETE /api/teams/:slug/channels/:channelId/messages/:messageId
  Future<Map<String, dynamic>> deleteMessage(
    String teamSlug,
    String channelId,
    String messageId,
  ) async {
    return delete('/api/teams/$teamSlug/channels/$channelId/messages/$messageId');
  }

  /// GET /api/teams/:slug/channels/:channelId/threads/:messageId
  Future<Map<String, dynamic>> getThread(
    String teamSlug,
    String channelId,
    String messageId,
  ) async {
    final raw = await get(
      '/api/teams/$teamSlug/channels/$channelId/threads/$messageId',
    );
    final data = raw['data'] as Map<String, dynamic>? ?? raw;
    return data;
  }

  /// POST /api/teams/:slug/channels/:channelId/messages — send a thread reply
  Future<Map<String, dynamic>> sendThreadReply(
    String teamSlug,
    String channelId,
    String parentMessageId,
    String content,
  ) async {
    return post('/api/teams/$teamSlug/channels/$channelId/messages', body: {
      'content': {'text': content},
      'thread_parent_id': parentMessageId,
    });
  }

  // ---------------------------------------------------------------------------
  // Reactions
  // ---------------------------------------------------------------------------

  /// POST /api/teams/:slug/channels/:id/messages/:id/reactions
  ///
  /// Toggles a reaction on a message (adds if not present, removes if present).
  Future<Map<String, dynamic>> toggleReaction(
    String teamSlug,
    String channelId,
    String messageId,
    String emoji,
  ) async {
    return post(
      '/api/teams/$teamSlug/channels/$channelId/messages/$messageId/reactions',
      body: {'emoji': emoji},
    );
  }

  // ---------------------------------------------------------------------------
  // Profiles
  // ---------------------------------------------------------------------------

  /// GET /api/teams/:slug/profiles
  Future<List<Map<String, dynamic>>> getProfiles(String teamSlug) async {
    final raw = await getRaw('/api/teams/$teamSlug/profiles');
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// GET /api/teams/:slug/profiles/:id
  Future<Map<String, dynamic>> getProfile(
    String teamSlug,
    String profileId,
  ) async {
    final raw = await get('/api/teams/$teamSlug/profiles/$profileId');
    final data = raw.containsKey('data') ? raw['data'] as Map<String, dynamic> : raw;
    return data;
  }

  /// PUT /api/teams/:slug/profiles/me
  Future<Map<String, dynamic>> updateMyProfile(
    String teamSlug, {
    String? displayName,
    String? email,
    String? phone,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['display_name'] = displayName;
    if (email != null) body['email'] = email;
    if (phone != null) body['phone'] = phone;
    return put('/api/teams/$teamSlug/profiles/me', body: body);
  }

  // ---------------------------------------------------------------------------
  // DMs
  // ---------------------------------------------------------------------------

  /// POST /api/teams/:slug/dms
  Future<Map<String, dynamic>> createDm(
    String teamSlug,
    List<String> profileIds,
  ) async {
    return post('/api/teams/$teamSlug/dms', body: {
      'profile_ids': profileIds,
    });
  }

  // ---------------------------------------------------------------------------
  // Apps & Commands
  // ---------------------------------------------------------------------------

  /// GET /api/teams/:slug/apps — list installed apps for a team.
  Future<List<Map<String, dynamic>>> getInstalledApps(String teamSlug) async {
    final raw = await getRaw('/api/teams/$teamSlug/apps');
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
    }
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  /// GET /api/teams/:slug/commands — list available slash commands for a team.
  Future<List<Map<String, dynamic>>> getCommands(String teamSlug) async {
    final raw = await getRaw('/api/teams/$teamSlug/commands');
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
    }
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  /// POST /api/teams/:slug/channels/:channelId/commands — execute a command.
  Future<Map<String, dynamic>> executeCommand(
    String teamSlug,
    String channelId,
    String command,
    String? args,
  ) async {
    return post('/api/teams/$teamSlug/channels/$channelId/commands', body: {
      'command': command,
      if (args != null) 'args': args,
    });
  }

  // ---------------------------------------------------------------------------
  // Media / File uploads
  // ---------------------------------------------------------------------------

  /// Maximum file size allowed (50 MB).
  static const maxFileSize = 50 * 1024 * 1024;

  /// Request a presigned upload URL from the server.
  ///
  /// POST /api/teams/:slug/media/presign
  Future<PresignedUpload> getUploadUrl(
    String teamSlug, {
    required String filename,
    required String contentType,
    required int size,
  }) async {
    final raw = await post('/api/teams/$teamSlug/media/presign', body: {
      'filename': filename,
      'content_type': contentType,
      'size': size,
    });
    final data =
        raw.containsKey('data') ? raw['data'] as Map<String, dynamic> : raw;
    return PresignedUpload(
      uploadId: data['upload_id']?.toString() ?? '',
      objectKey: data['object_key']?.toString() ?? '',
      uploadUrl: data['upload_url']?.toString() ?? data['presigned_url']?.toString() ?? '',
      uploadMethod: data['upload_method']?.toString() ?? 'PUT',
      uploadHeaders: (data['upload_headers'] as Map?)?.cast<String, String>() ?? {},
      expiresAt: data['expires_at']?.toString(),
    );
  }

  /// Upload file bytes to a presigned URL (direct to MinIO/S3).
  ///
  /// Returns the HTTP status code.
  Future<int> uploadFileToPresignedUrl(
    String uploadUrl,
    Uint8List bytes,
    String contentType, {
    Map<String, String>? headers,
  }) async {
    final uploadHeaders = <String, String>{
      'Content-Type': contentType,
      ...?headers,
    };
    final response = await _http.put(
      Uri.parse(uploadUrl),
      headers: uploadHeaders,
      body: bytes,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.statusCode;
    }
    throw MsgrApiException(
      statusCode: response.statusCode,
      message: 'Upload failed: ${response.body}',
    );
  }

  /// Get a presigned download URL for a media object.
  ///
  /// GET /api/teams/:slug/media/:objectKey/url
  Future<String> getDownloadUrl(String teamSlug, String objectKey) async {
    final encoded = Uri.encodeComponent(objectKey);
    final raw = await get('/api/teams/$teamSlug/media/$encoded/url');
    final data =
        raw.containsKey('data') ? raw['data'] as Map<String, dynamic> : raw;
    return data['download_url']?.toString() ?? '';
  }

  /// Convenience: upload a file and return its object_key.
  ///
  /// Validates file size, requests presigned URL, uploads bytes, returns the key.
  Future<String> uploadFileToChannel(
    String teamSlug,
    String channelId, {
    required String filename,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (bytes.length > maxFileSize) {
      throw const MsgrApiException(
        statusCode: 413,
        message: 'File exceeds 50 MB size limit',
      );
    }

    final presign = await getUploadUrl(
      teamSlug,
      filename: filename,
      contentType: contentType,
      size: bytes.length,
    );

    await uploadFileToPresignedUrl(
      presign.uploadUrl,
      bytes,
      contentType,
      headers: presign.uploadHeaders,
    );

    return presign.objectKey;
  }
}

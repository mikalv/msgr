import 'dart:convert';

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

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (accountId != null) {
      headers['X-Account-Id'] = accountId!;
    }
    if (profileId != null) {
      headers['X-Profile-Id'] = profileId!;
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
  // Low-level HTTP verbs
  // ---------------------------------------------------------------------------

  Future<dynamic> getRaw(String path, {Map<String, String>? query}) async {
    final response =
        await _http.get(_uri(path, query: query), headers: _headers());
    return _handleResponseRaw(response);
  }

  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? query}) async {
    final response =
        await _http.get(_uri(path, query: query), headers: _headers());
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String path,
      {Map<String, dynamic>? body}) async {
    final response = await _http.post(
      _uri(path),
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(String path,
      {Map<String, dynamic>? body}) async {
    final response = await _http.put(
      _uri(path),
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final response = await _http.delete(_uri(path), headers: _headers());
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

    return SessionResult(
      accountId: accountIdValue,
      profileId: profileIdValue,
      email: account['email'] as String?,
      displayName: account['display_name'] as String?,
      profiles: profiles,
    );
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
  }) async {
    final channelSlug = slug ??
        name
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-|-$'), '');
    return post('/api/teams/$teamSlug/channels', body: {
      'name': name,
      'slug': channelSlug,
      if (icon != null) 'icon': icon,
    });
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
    String content,
  ) async {
    return post('/api/teams/$teamSlug/channels/$channelId/messages', body: {
      'content': {'text': content},
    });
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
}

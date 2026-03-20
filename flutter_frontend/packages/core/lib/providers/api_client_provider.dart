import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'auth_state_provider.dart';

/// Lightweight HTTP client for the team-scoped REST API.
///
/// All requests are authenticated using X-Account-Id and X-Profile-Id headers.
/// The base URL points to the dev gateway by default and can be overridden.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    this.accountIdProvider,
    this.profileIdProvider,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String? Function()? accountIdProvider;
  final String? Function()? profileIdProvider;
  final http.Client _http;

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final accountId = accountIdProvider?.call();
    final profileId = profileIdProvider?.call();
    if (accountId != null) {
      headers['X-Account-Id'] = accountId;
    }
    if (profileId != null) {
      headers['X-Profile-Id'] = profileId;
    }
    return headers;
  }

  Uri _uri(String path, {Map<String, String>? query}) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Future<dynamic> getRaw(
    String path, {
    Map<String, String>? query,
  }) async {
    final response =
        await _http.get(_uri(path, query: query), headers: _headers());
    return _handleResponseRaw(response);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    final response =
        await _http.get(_uri(path, query: query), headers: _headers());
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _http.post(
      _uri(path),
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
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

  // -----------------------------------------------------------------------
  // High-level API methods
  // -----------------------------------------------------------------------

  /// GET /api/teams
  Future<List<Map<String, dynamic>>> getTeams() async {
    final raw = await getRaw('/api/teams');
    if (raw is List) {
      return raw.cast<Map<String, dynamic>>();
    }
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
      return [raw];
    }
    return [];
  }

  /// POST /api/teams
  Future<Map<String, dynamic>> createTeam({
    required String name,
    required String slug,
    String? description,
  }) async {
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

  /// GET /api/teams/:slug/channels
  Future<List<Map<String, dynamic>>> getChannels(String slug) async {
    final raw = await getRaw('/api/teams/$slug/channels');
    if (raw is List) {
      return raw.cast<Map<String, dynamic>>();
    }
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// GET /api/teams/:slug/channels/:id/messages
  Future<List<Map<String, dynamic>>> getMessages(
    String slug,
    String channelId, {
    int limit = 50,
    String? before,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (before != null) query['before'] = before;
    final raw =
        await getRaw('/api/teams/$slug/channels/$channelId/messages', query: query);
    if (raw is List) {
      return raw.cast<Map<String, dynamic>>();
    }
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// POST /api/teams/:slug/channels/:id/messages
  Future<Map<String, dynamic>> sendMessage(
    String slug,
    String channelId,
    String content,
  ) async {
    return post('/api/teams/$slug/channels/$channelId/messages', body: {
      'content': {'text': content},
    });
  }

  /// POST /api/teams/:slug/dms
  Future<Map<String, dynamic>> createDm(
    String slug,
    List<String> profileIds,
  ) async {
    return post('/api/teams/$slug/dms', body: {
      'profile_ids': profileIds,
    });
  }

  // -----------------------------------------------------------------------
  // Response handling
  // -----------------------------------------------------------------------

  dynamic _handleResponseRaw(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return <String, dynamic>{};
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return <String, dynamic>{};
      }
    }
    throw ApiClientException(
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
    throw ApiClientException(
      statusCode: response.statusCode,
      message: response.body,
    );
  }
}

class ApiClientException implements Exception {
  const ApiClientException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiClientException($statusCode): $message';
}

/// Global API client provider wired to the current auth state (header-based).
final apiClientProvider = Provider<ApiClient>((ref) {
  final simpleAuth = ref.watch(simpleAuthProvider);
  return ApiClient(
    baseUrl: 'https://dev.msgr.no',
    accountIdProvider: () => simpleAuth.accountId,
    profileIdProvider: () => simpleAuth.profileId,
  );
});

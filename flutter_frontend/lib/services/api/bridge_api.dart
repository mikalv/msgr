import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/config/backend_environment.dart';
import 'package:messngr/features/bridges/models/bridge_auth_session.dart';
import 'package:messngr/features/bridges/models/bridge_catalog_entry.dart';

import 'chat_api.dart' show AccountIdentity, ApiException;

class BridgeApi {
  BridgeApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<BridgeCatalogEntry>> listCatalog({
    required AccountIdentity current,
  }) async {
    final response = await _client.get(
      backendApiUri('bridges/catalog'),
      headers: _authHeaders(current),
    );

    final decoded = _decodeBody(response);
    final List<dynamic> data = decoded['data'] as List<dynamic>? ?? const [];
    return data
        .map((item) => BridgeCatalogEntry.fromJson(
            item is Map<String, dynamic> ? item : const <String, dynamic>{}))
        .toList(growable: false);
  }

  Future<BridgeAuthSession> startSession({
    required AccountIdentity current,
    required String bridgeId,
    Map<String, dynamic>? payload,
  }) async {
    final body = <String, dynamic>{
      if (payload != null) 'session': payload,
    };

    final response = await _client.post(
      backendApiUri('bridges/$bridgeId/sessions'),
      headers: _authHeaders(current),
      body: jsonEncode(body),
    );

    final decoded = _decodeBody(response);
    final data = decoded['data'] as Map<String, dynamic>? ?? const {};
    return BridgeAuthSession.fromJson(data);
  }

  Future<BridgeAuthSession> fetchSession({
    required AccountIdentity current,
    required String sessionId,
  }) async {
    final response = await _client.get(
      backendApiUri('bridges/sessions/$sessionId'),
      headers: _authHeaders(current),
    );

    final decoded = _decodeBody(response);
    final data = decoded['data'] as Map<String, dynamic>? ?? const {};
    return BridgeAuthSession.fromJson(data);
  }

  Future<BridgeAuthSession> submitCredentials({
    required AccountIdentity current,
    required String bridgeId,
    required String sessionId,
    required Map<String, dynamic> credentials,
  }) async {
    final response = await _client.post(
      backendApiUri('bridges/$bridgeId/sessions/$sessionId/credentials'),
      headers: _authHeaders(current),
      body: jsonEncode({'credentials': credentials}),
    );

    final decoded = _decodeBody(response);
    final data = decoded['data'] as Map<String, dynamic>? ?? const {};
    return BridgeAuthSession.fromJson(data);
  }

  Uri resolveAuthorizationUrl(String path) {
    return _resolveBackendPath(path);
  }

  Uri resolveCallbackUrl(String path) {
    return _resolveBackendPath(path);
  }

  Uri _resolveBackendPath(String path) {
    final root = BackendEnvironment.instance.apiBaseUri;
    final sanitized = path.startsWith('/') ? path.substring(1) : path;
    final segments = sanitized
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    return root.replace(pathSegments: segments);
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    final status = response.statusCode;
    final body = response.body.isEmpty ? '{}' : response.body;
    final decoded = jsonDecode(body);
    if (status < 200 || status >= 300) {
      throw ApiException(status, body);
    }
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return const {};
  }

  Map<String, String> _authHeaders(AccountIdentity identity) {
    return {
      'Content-Type': 'application/json',
      'x-msgr-account-id': identity.accountId,
      'x-msgr-profile-id': identity.profileId,
    };
  }
}

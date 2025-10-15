import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants.dart';
import '../models/auth_challenge.dart';
import '../models/noise_handshake.dart';
import '../network/server_resolver.dart';

class RegistrationApi {
  RegistrationApi({
    http.Client? httpClient,
    ServerResolver? serverResolver,
    String? userAgent,
  })  : _client = httpClient ?? http.Client(),
        _resolver = serverResolver ?? const ServerResolver(),
        _userAgent = userAgent ?? MsgrConstants.kUserAgentNameString;

  final http.Client _client;
  final ServerResolver _resolver;
  final String _userAgent;

  Map<String, String> _jsonHeaders({Map<String, String>? extra}) {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'User-Agent': _userAgent,
    };
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  Future<bool> registerDevice({
    required String deviceId,
    required Map<String, dynamic> keyData,
    required Map<String, dynamic> deviceInfo,
    Map<String, dynamic>? appInfo,
  }) async {
    final url = _resolver.resolveAuth('/api/v1/device/register');
    final body = {
      'from': deviceId,
      'payload': {
        'keyData': keyData,
        'deviceInfo': deviceInfo,
        if (appInfo != null && appInfo.isNotEmpty) 'appInfo': appInfo,
      },
    };

    final response = await _client.post(
      url,
      headers: _jsonHeaders(),
      body: jsonEncode(body),
    );
    return response.statusCode == 200;
  }

  Future<bool> syncDeviceContext({
    required String deviceId,
    required Map<String, dynamic> deviceInfo,
    Map<String, dynamic>? appInfo,
  }) async {
    final url = _resolver.resolveAuth('/api/v1/device/context');
    final payload = {
      'from': deviceId,
      'deviceInfo': deviceInfo,
      if (appInfo != null && appInfo.isNotEmpty) 'appInfo': appInfo,
    };
    final response = await _client.post(
      url,
      headers: _jsonHeaders(),
      body: jsonEncode(payload),
    );
    return response.statusCode == 200;
  }

  Future<AuthChallenge?> requestChallenge({
    required String channel,
    required String identifier,
    required String deviceId,
  }) async {
    final url = _resolver.resolveAuth('/api/auth/challenge');
    final body = {
      'channel': channel,
      'identifier': identifier,
      'device_id': deviceId,
    };
    final response = await _client.post(
      url,
      headers: _jsonHeaders(),
      body: jsonEncode(body),
    );
    if (response.statusCode != 201) {
      return null;
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthChallenge.fromJson(decoded);
  }

  Future<Map<String, dynamic>?> verifyCode({
    required String challengeId,
    required String code,
    String? displayName,
    String? noiseSessionId,
    String? noiseSignature,
    DateTime? lastHandshakeAt,
  }) async {
    final url = _resolver.resolveAuth('/api/auth/verify');
    final payload = {
      'challenge_id': challengeId,
      'code': code,
      if (displayName != null && displayName.isNotEmpty)
        'display_name': displayName,
      if (noiseSessionId != null && noiseSessionId.isNotEmpty)
        'noise_session_id': noiseSessionId,
      if (noiseSignature != null && noiseSignature.isNotEmpty)
        'noise_signature': noiseSignature,
      if (lastHandshakeAt != null)
        'last_handshake_at': lastHandshakeAt.toUtc().toIso8601String(),
    };
    final response = await _client.post(
      url,
      headers: _jsonHeaders(),
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      return null;
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<NoiseHandshakeSession?> createNoiseHandshake() async {
    final url = _resolver.resolveAuth('/api/noise/handshake');
    final response = await _client.post(
      url,
      headers: _jsonHeaders(),
      body: jsonEncode(const {}),
    );

    if (response.statusCode != 200) {
      return null;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final session = NoiseHandshakeSession.fromJson(data);
    if (session.sessionId.isEmpty ||
        session.signature.isEmpty ||
        session.deviceKey.isEmpty) {
      return null;
    }

    return session;
  }

  Future<Map<String, dynamic>?> completeOidc({
    required String provider,
    required String subject,
    String? email,
    String? name,
  }) async {
    final url = _resolver.resolveAuth('/api/auth/oidc');
    final payload = {
      'provider': provider,
      'subject': subject,
      if (email != null) 'email': email,
      if (name != null) 'name': name,
    };
    final response = await _client.post(
      url,
      headers: _jsonHeaders(),
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      return null;
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> createProfile({
    required String teamName,
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final url = _resolver.resolveTeam(teamName, '/v1/api/profiles');
    final response = await _client.post(
      url,
      headers: _jsonHeaders(
        extra: {'Authorization': 'Bearer $token'},
      ),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      return null;
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> createTeam({
    required String teamName,
    required String description,
    required String token,
    required String uid,
  }) async {
    final url = _resolver.resolveMain('/public/v1/api/teams');
    final payload = {
      'team_name': teamName,
      'description': description,
      'uid': uid,
    };
    final response = await _client.post(
      url,
      headers: _jsonHeaders(
        extra: {'Authorization': 'Bearer $token'},
      ),
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      return null;
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> selectTeam({
    required String teamName,
    required String token,
  }) async {
    final url = _resolver.resolveMain('/public/v1/api/select/team/$teamName');
    final response = await _client.post(
      url,
      headers: _jsonHeaders(
        extra: {'Authorization': 'Bearer $token'},
      ),
    );
    if (response.statusCode != 200) {
      return null;
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> listTeams({required String token}) async {
    final url = _resolver.resolveMain('/public/v1/api/teams');
    final response = await _client.get(
      url,
      headers: _jsonHeaders(
        extra: {'Authorization': 'Bearer $token'},
      ),
    );
    if (response.statusCode != 200) {
      return const [];
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['status'] != 'ok') {
      return const [];
    }
    final teams = decoded['teams'];
    if (teams is List<dynamic>) {
      return teams;
    }
    return const [];
  }

  Future<Map<String, dynamic>?> refreshSession({
    required String deviceId,
    required String refreshToken,
  }) async {
    final url = _resolver.resolveAuth('/api/v1/refresh_token');
    final payload = {
      'from': deviceId,
      'token': refreshToken,
    };
    final response = await _client.post(
      url,
      headers: _jsonHeaders(),
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      return null;
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:messngr/config/app_constants.dart';

import 'chat_api.dart' show ApiException;

class NoiseHandshakeResponse {
  const NoiseHandshakeResponse({
    required this.sessionId,
    required this.signature,
    required this.deviceKey,
    required this.devicePrivateKey,
    required this.expiresAt,
    required this.server,
  });

  final String sessionId;
  final String signature;
  final String deviceKey;
  final String devicePrivateKey;
  final DateTime expiresAt;
  final NoiseServerInfo server;
}

class NoiseServerInfo {
  const NoiseServerInfo({
    required this.protocol,
    required this.prologue,
    this.fingerprint,
    this.publicKeyBase64,
  });

  final String protocol;
  final String prologue;
  final String? fingerprint;
  final String? publicKeyBase64;
}

class OtpChallenge {
  const OtpChallenge({
    required this.id,
    this.debugCode,
    this.expiresAt,
  });

  final String id;
  final String? debugCode;
  final DateTime? expiresAt;
}

class AuthSessionResult {
  const AuthSessionResult({
    required this.accountId,
    required this.accountDisplayName,
    required this.profileId,
    required this.profileName,
    required this.noiseToken,
    required this.noiseSessionId,
  });

  final String accountId;
  final String accountDisplayName;
  final String profileId;
  final String profileName;
  final String noiseToken;
  final String noiseSessionId;
}

class AuthApi {
  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<NoiseHandshakeResponse> createDevHandshake() async {
    final response = await _client.post(
      backendApiUri('noise/handshake'),
      headers: {'Content-Type': 'application/json'},
    );

    final decoded = _decodeBody(response);
    final data = decoded['data'] as Map<String, dynamic>? ?? const {};

    final sessionId = data['session_id'] as String? ?? '';
    if (sessionId.isEmpty) {
      throw const ApiException(500, 'noise_handshake_missing_session');
    }

    final serverMap = data['server'] as Map<String, dynamic>? ?? const {};
    final server = NoiseServerInfo(
      protocol: serverMap['protocol'] as String? ?? 'Noise_NX_25519_ChaChaPoly_Blake2b',
      prologue: serverMap['prologue'] as String? ?? 'msgr-noise/v1',
      fingerprint: serverMap['fingerprint'] as String?,
      publicKeyBase64: serverMap['public_key'] as String?,
    );

    return NoiseHandshakeResponse(
      sessionId: sessionId,
      signature: data['signature'] as String? ?? '',
      deviceKey: data['device_key'] as String? ?? '',
      devicePrivateKey: data['device_private_key'] as String? ?? '',
      expiresAt: DateTime.tryParse(data['expires_at'] as String? ?? '') ?? DateTime.now().toUtc(),
      server: server,
    );
  }

  Future<OtpChallenge> requestEmailChallenge({
    required String email,
    required String deviceKey,
  }) async {
    final response = await _client.post(
      backendApiUri('auth/challenge'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'channel': 'email',
        'identifier': email,
        'device_id': deviceKey,
      }),
    );

    final decoded = _decodeBody(response);
    final id = decoded['id'] as String? ?? '';
    if (id.isEmpty) {
      throw const ApiException(500, 'challenge_missing_id');
    }

    final expires = decoded['expires_at'] as String? ?? '';

    return OtpChallenge(
      id: id,
      debugCode: decoded['debug_code'] as String?,
      expiresAt: expires.isEmpty ? null : DateTime.tryParse(expires),
    );
  }

  Future<AuthSessionResult> verifyCode({
    required String challengeId,
    required String code,
    required String noiseSessionId,
    required String noiseSignature,
    String? displayName,
  }) async {
    final response = await _client.post(
      backendApiUri('auth/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'challenge_id': challengeId,
        'code': code,
        if (displayName != null && displayName.isNotEmpty) 'display_name': displayName,
        'noise_session_id': noiseSessionId,
        'noise_signature': noiseSignature,
        'last_handshake_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );

    final decoded = _decodeBody(response);
    final account = decoded['account'] as Map<String, dynamic>? ?? const {};
    final profile = decoded['profile'] as Map<String, dynamic>? ?? const {};
    final noise = decoded['noise_session'] as Map<String, dynamic>? ?? const {};

    final noiseToken = noise['token'] as String? ?? '';
    final noiseId = noise['id'] as String? ?? noiseSessionId;
    if (noiseToken.isEmpty) {
      throw const ApiException(500, 'noise_session_missing_token');
    }

    final accountId = account['id'] as String? ?? '';
    final profileId = profile['id'] as String? ?? '';
    if (accountId.isEmpty || profileId.isEmpty) {
      throw const ApiException(500, 'auth_session_missing_profile');
    }

    return AuthSessionResult(
      accountId: accountId,
      accountDisplayName: account['display_name'] as String? ?? '',
      profileId: profileId,
      profileName: profile['name'] as String? ?? '',
      noiseToken: noiseToken,
      noiseSessionId: noiseId,
    );
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

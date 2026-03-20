import 'dart:convert';
import 'package:http/http.dart' as http;

/// Result of POST /api/v1/auth/challenge
class ChallengeResult {
  const ChallengeResult({
    required this.id,
    this.channel,
    this.debugCode,
    this.targetHint,
  });

  final String id;
  final String? channel;
  final String? debugCode;
  final String? targetHint;
}

/// Result of POST /api/v1/auth/verify
class SessionResult {
  const SessionResult({
    required this.accountId,
    required this.profileId,
    this.email,
    this.displayName,
    this.profiles,
  });

  final String accountId;
  final String profileId;
  final String? email;
  final String? displayName;
  final List<Map<String, dynamic>>? profiles;
}

/// Simple auth service that talks directly to the dev.msgr.no REST API.
///
/// Uses email OTP flow:
///   1. requestChallenge(email) -> ChallengeResult with debug_code
///   2. verifyCode(challengeId, code) -> SessionResult with account_id + profile_id
class AuthService {
  AuthService({http.Client? client})
      : _client = client ?? http.Client();

  static const baseUrl = 'https://dev.msgr.no';
  final http.Client _client;

  /// POST /api/v1/auth/challenge
  Future<ChallengeResult> requestChallenge(String identifier, {String channel = 'email'}) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/auth/challenge'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'channel': channel,
        'identifier': identifier,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthServiceException(
        response.statusCode,
        'Challenge request failed: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) {
      throw AuthServiceException(500, 'No challenge ID in response');
    }

    return ChallengeResult(
      id: id,
      channel: data['channel'] as String?,
      debugCode: data['debug_code'] as String?,
      targetHint: data['target_hint'] as String?,
    );
  }

  /// POST /api/v1/auth/verify
  Future<SessionResult> verifyCode(String challengeId, String code) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/auth/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'challenge_id': challengeId,
        'code': code,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthServiceException(
        response.statusCode,
        'Verify failed: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // Extract account info
    final account = data['account'] as Map<String, dynamic>? ?? {};
    final accountId = account['id'] as String? ?? '';
    if (accountId.isEmpty) {
      throw AuthServiceException(500, 'No account ID in verify response');
    }

    // Extract profile ID - either top-level or from first profile in account
    var profileId = data['profile_id'] as String? ?? '';
    if (profileId.isEmpty) {
      final profiles = account['profiles'] as List? ?? [];
      if (profiles.isNotEmpty) {
        final firstProfile = profiles.first as Map<String, dynamic>;
        profileId = firstProfile['id'] as String? ?? '';
      }
    }
    if (profileId.isEmpty) {
      throw AuthServiceException(500, 'No profile ID in verify response');
    }

    final profiles = (account['profiles'] as List?)
        ?.map((p) => p as Map<String, dynamic>)
        .toList();

    return SessionResult(
      accountId: accountId,
      profileId: profileId,
      email: account['email'] as String?,
      displayName: account['display_name'] as String?,
      profiles: profiles,
    );
  }
}

class AuthServiceException implements Exception {
  const AuthServiceException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'AuthServiceException($statusCode): $message';
}

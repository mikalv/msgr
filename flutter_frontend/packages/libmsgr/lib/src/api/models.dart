/// Auth and API response models for MsgrApiClient.
///
/// Pure Dart -- no Flutter dependencies.

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
    this.accessToken,
    this.refreshToken,
  });

  final String accountId;
  final String profileId;
  final String? email;
  final String? displayName;
  final List<Map<String, dynamic>>? profiles;

  /// JWT access token (short-lived, 15 min).
  final String? accessToken;

  /// JWT refresh token (long-lived, 30 days).
  final String? refreshToken;
}

/// Exception thrown by [MsgrApiClient] on non-2xx responses.
class MsgrApiException implements Exception {
  const MsgrApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'MsgrApiException($statusCode): $message';
}

/// Result of POST /api/teams/:slug/media/presign
class PresignedUpload {
  const PresignedUpload({
    required this.uploadId,
    required this.objectKey,
    required this.uploadUrl,
    this.uploadMethod = 'PUT',
    this.uploadHeaders = const {},
    this.expiresAt,
  });

  final String uploadId;
  final String objectKey;
  final String uploadUrl;
  final String uploadMethod;
  final Map<String, String> uploadHeaders;
  final String? expiresAt;
}

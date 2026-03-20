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
  });

  final String accountId;
  final String profileId;
  final String? email;
  final String? displayName;
  final List<Map<String, dynamic>>? profiles;
}

/// Exception thrown by [MsgrApiClient] on non-2xx responses.
class MsgrApiException implements Exception {
  const MsgrApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'MsgrApiException($statusCode): $message';
}

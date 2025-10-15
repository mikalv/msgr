class NoiseHandshakeSession {
  NoiseHandshakeSession({
    required this.sessionId,
    required this.signature,
    required this.deviceKey,
    required this.devicePrivateKey,
    required this.expiresAt,
    this.server,
  });

  final String sessionId;
  final String signature;
  final String deviceKey;
  final String devicePrivateKey;
  final DateTime expiresAt;
  final Map<String, dynamic>? server;

  factory NoiseHandshakeSession.fromJson(Map<String, dynamic> json) {
    final data = Map<String, dynamic>.from(json);
    final expiresRaw = data['expires_at'] as String? ?? '';
    final expiresAt = DateTime.tryParse(expiresRaw)?.toUtc() ??
        DateTime.now().toUtc().add(const Duration(minutes: 5));

    return NoiseHandshakeSession(
      sessionId: data['session_id'] as String? ?? '',
      signature: data['signature'] as String? ?? '',
      deviceKey: data['device_key'] as String? ?? '',
      devicePrivateKey: data['device_private_key'] as String? ?? '',
      expiresAt: expiresAt,
      server: data['server'] is Map
          ? Map<String, dynamic>.from(data['server'] as Map)
          : null,
    );
  }

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  bool get shouldRefresh {
    final threshold = expiresAt.subtract(const Duration(seconds: 30));
    return DateTime.now().toUtc().isAfter(threshold);
  }
}

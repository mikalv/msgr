class AuthChallenge {
  AuthChallenge({
    required this.id,
    required this.channel,
    required this.expiresAt,
    this.targetHint,
    this.debugCode,
  });

  final String id;
  final String channel;
  final DateTime expiresAt;
  final String? targetHint;
  final String? debugCode;

  factory AuthChallenge.fromJson(Map<String, dynamic> json) {
    return AuthChallenge(
      id: json['id'] as String,
      channel: json['channel'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      targetHint: json['target_hint'] as String?,
      debugCode: json['debug_code'] as String?,
    );
  }
}


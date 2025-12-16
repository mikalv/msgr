import 'package:flutter/foundation.dart';

/// Represents an authentication session for linking a bridge connector.
@immutable
class BridgeAuthSession {
  const BridgeAuthSession({
    required this.id,
    required this.accountId,
    required this.service,
    required this.state,
    required this.loginMethod,
    required this.authSurface,
    required this.clientContext,
    required this.metadata,
    required this.catalogSnapshot,
    required this.expiresAt,
    required this.lastTransitionAt,
    required this.authorizationPath,
    required this.callbackPath,
  });

  factory BridgeAuthSession.fromJson(Map<String, dynamic> json) {
    return BridgeAuthSession(
      id: json['id'] as String? ?? '',
      accountId: json['account_id'] as String? ?? '',
      service: json['service'] as String? ?? '',
      state: json['state'] as String? ?? 'awaiting_user',
      loginMethod: json['login_method'] as String? ?? '',
      authSurface: json['auth_surface'] as String? ?? '',
      clientContext: _normalizeMap(json['client_context']),
      metadata: _normalizeMap(json['metadata']),
      catalogSnapshot: _normalizeMap(json['catalog_snapshot']),
      expiresAt: json['expires_at']?.toString(),
      lastTransitionAt: json['last_transition_at']?.toString(),
      authorizationPath: json['authorization_path']?.toString() ?? '',
      callbackPath: json['callback_path']?.toString() ?? '',
    );
  }

  final String id;
  final String accountId;
  final String service;
  final String state;
  final String loginMethod;
  final String authSurface;
  final Map<String, dynamic> clientContext;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> catalogSnapshot;
  final String? expiresAt;
  final String? lastTransitionAt;
  final String authorizationPath;
  final String callbackPath;

  bool get isLinked => state == 'linked';
  bool get isAwaitingUser => state == 'awaiting_user';
  bool get isCompleting => state == 'completing';

  BridgeAuthSession copyWith({
    String? state,
    Map<String, dynamic>? metadata,
  }) {
    return BridgeAuthSession(
      id: id,
      accountId: accountId,
      service: service,
      state: state ?? this.state,
      loginMethod: loginMethod,
      authSurface: authSurface,
      clientContext: clientContext,
      metadata: metadata ?? this.metadata,
      catalogSnapshot: catalogSnapshot,
      expiresAt: expiresAt,
      lastTransitionAt: lastTransitionAt,
      authorizationPath: authorizationPath,
      callbackPath: callbackPath,
    );
  }

  static Map<String, dynamic> _normalizeMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, dynamic val) => MapEntry(key.toString(), val));
    }
    return const <String, dynamic>{};
  }
}

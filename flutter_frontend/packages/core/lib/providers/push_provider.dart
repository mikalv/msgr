import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'auth_state_provider.dart';
import 'msgr_client_provider.dart';

/// Manages push notification token registration.
/// Receives APNS/FCM tokens from native and sends them to the backend.
class PushNotificationManager {
  PushNotificationManager(this._ref);

  final Ref _ref;
  static const _channel = MethodChannel('no.msgr.app/push');
  String? _lastRegisteredToken;

  /// Initialize: listen for token updates from native side.
  void init() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onPushToken':
          final token = call.arguments as String?;
          if (token != null && token.isNotEmpty) {
            await _registerToken(token, 'apns');
          }
        case 'onPushNotification':
          // Handle foreground notification tap
          final data = call.arguments as Map?;
          // TODO: Navigate to channel/message
          break;
      }
    });

    // Request token from native
    _channel.invokeMethod('requestToken');
  }

  Future<void> _registerToken(String token, String platform) async {
    if (token == _lastRegisteredToken) return;

    final auth = _ref.read(simpleAuthProvider);
    if (!auth.isLoggedIn) return;

    try {
      final client = _ref.read(msgrApiProvider);
      await client.post('/api/push/register', body: {
        'token': token,
        'platform': platform,
        'device_name': 'iOS',
      });
      _lastRegisteredToken = token;
    } catch (_) {
      // Will retry on next app launch
    }
  }
}

final pushManagerProvider = Provider<PushNotificationManager>((ref) {
  final manager = PushNotificationManager(ref);

  // Auto-init when logged in
  ref.listen<SimpleAuthState>(simpleAuthProvider, (prev, next) {
    if (next.isLoggedIn && !next.isLoading) {
      manager.init();
    }
  }, fireImmediately: true);

  return manager;
});

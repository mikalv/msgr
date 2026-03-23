import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'auth_state_provider.dart';
import 'msgr_client_provider.dart';

// Conditionally import dart:io only on non-web platforms
import 'push_provider_io.dart' if (dart.library.html) 'push_provider_stub.dart';

class PushNotificationManager {
  PushNotificationManager(this._ref);

  final Ref _ref;
  String? _lastRegisteredToken;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) return;

    final auth = _ref.read(simpleAuthProvider);
    if (!auth.isLoggedIn) return;

    final token = await readApnsToken();
    if (token != null && token.isNotEmpty) {
      debugPrint('[Push] Found APNS token: ${token.substring(0, 16.clamp(0, token.length))}...');
      await _registerToken(token);
    } else {
      Future.delayed(const Duration(seconds: 5), () async {
        final t = await readApnsToken();
        if (t != null && t.isNotEmpty) await _registerToken(t);
      });
    }
  }

  Future<void> _registerToken(String token) async {
    if (token == _lastRegisteredToken) return;
    try {
      final client = _ref.read(msgrApiProvider);
      await client.post('/api/push/register', body: {
        'token': token,
        'platform': 'apns',
        'device_name': defaultTargetPlatform == TargetPlatform.iOS ? 'iOS' : 'macOS',
      });
      debugPrint('[Push] Token registered with backend!');
      _lastRegisteredToken = token;
    } catch (e) {
      debugPrint('[Push] Registration failed: $e');
    }
  }
}

final pushManagerProvider = Provider<PushNotificationManager>((ref) {
  final manager = PushNotificationManager(ref);
  ref.listen<SimpleAuthState>(simpleAuthProvider, (prev, next) {
    if (next.isLoggedIn && !next.isLoading) {
      manager.init();
    }
  }, fireImmediately: true);
  return manager;
});

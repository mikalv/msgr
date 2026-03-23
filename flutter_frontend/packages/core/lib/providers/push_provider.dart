import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_state_provider.dart';
import 'msgr_client_provider.dart';

/// Reads APNS token from UserDefaults (set by native AppDelegate)
/// and registers it with the backend when the user is logged in.
class PushNotificationManager {
  PushNotificationManager(this._ref);

  final Ref _ref;
  String? _lastRegisteredToken;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Only on iOS
    if (!Platform.isIOS) return;

    final auth = _ref.read(simpleAuthProvider);
    if (!auth.isLoggedIn) return;

    // Read token from UserDefaults (set by native AppDelegate)
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('apns_device_token');

    if (token != null && token.isNotEmpty) {
      debugPrint('[Push] Found APNS token: ${token.substring(0, 16)}...');
      await _registerToken(token);
    } else {
      debugPrint('[Push] No APNS token found in UserDefaults');
      // Retry after a delay — token might not be ready yet
      Future.delayed(const Duration(seconds: 5), () async {
        final prefs2 = await SharedPreferences.getInstance();
        final token2 = prefs2.getString('apns_device_token');
        if (token2 != null && token2.isNotEmpty) {
          debugPrint('[Push] Found APNS token on retry: ${token2.substring(0, 16)}...');
          await _registerToken(token2);
        }
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
        'device_name': 'iOS',
      });
      debugPrint('[Push] Token registered with backend');
      _lastRegisteredToken = token;
    } catch (e) {
      debugPrint('[Push] Registration failed: $e');
    }
  }
}

final pushManagerProvider = Provider<PushNotificationManager>((ref) {
  return PushNotificationManager(ref);
});

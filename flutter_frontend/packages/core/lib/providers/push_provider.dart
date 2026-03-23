import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path_provider/path_provider.dart';

import 'auth_state_provider.dart';
import 'msgr_client_provider.dart';

/// Registers APNS device token with backend.
/// Native side writes token to a file; Flutter reads it.
class PushNotificationManager {
  PushNotificationManager(this._ref);

  final Ref _ref;
  String? _lastRegisteredToken;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    debugPrint('[Push] init() called, platform=${Platform.operatingSystem}');

    if (!Platform.isIOS && !Platform.isMacOS) return;

    final auth = _ref.read(simpleAuthProvider);
    debugPrint('[Push] isLoggedIn=${auth.isLoggedIn}');
    if (!auth.isLoggedIn) return;

    // Try reading token from file (written by native AppDelegate)
    await _tryRegisterFromFile();

    // Retry after delay if token wasn't available yet
    if (_lastRegisteredToken == null) {
      Future.delayed(const Duration(seconds: 5), _tryRegisterFromFile);
    }
  }

  Future<void> _tryRegisterFromFile() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/apns_token.txt');

      if (await file.exists()) {
        final token = (await file.readAsString()).trim();
        if (token.isNotEmpty) {
          debugPrint('[Push] Found APNS token: ${token.substring(0, 16.clamp(0, token.length))}...');
          await _registerToken(token);
        }
      } else {
        debugPrint('[Push] No apns_token.txt found at ${file.path}');
      }
    } catch (e) {
      debugPrint('[Push] Error reading token: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    if (token == _lastRegisteredToken) return;

    try {
      final client = _ref.read(msgrApiProvider);
      await client.post('/api/push/register', body: {
        'token': token,
        'platform': 'apns',
        'device_name': Platform.isIOS ? 'iOS' : 'macOS',
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

  // Auto-init after auth is ready
  ref.listen<SimpleAuthState>(simpleAuthProvider, (prev, next) {
    if (next.isLoggedIn && !next.isLoading) {
      manager.init();
    }
  }, fireImmediately: true);

  return manager;
});

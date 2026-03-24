import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'auth_state_provider.dart';
import 'msgr_client_provider.dart';

// Conditional import for web-only JS interop
import 'web_push_stub.dart' if (dart.library.html) 'web_push_web.dart' as impl;

final _log = Logger('WebPushProvider');

class WebPushManager {
  WebPushManager(this._ref);

  final Ref _ref;
  bool _subscribed = false;
  String? _vapidKey;

  /// Whether we already have a subscription registered.
  bool get isSubscribed => _subscribed;

  /// Whether web push is available on this platform.
  bool get isAvailable => kIsWeb;

  /// Store the VAPID key for later use (when user clicks "enable").
  void setVapidKey(String key) => _vapidKey = key;

  /// Subscribe to web push. MUST be called from a user gesture (click).
  Future<bool> subscribe() async {
    if (!kIsWeb || _subscribed) return _subscribed;

    final key = _vapidKey;
    if (key == null) {
      _log.warning('No VAPID key available');
      return false;
    }

    try {
      _log.info('Subscribing to web push...');
      final subscription = await impl.subscribeToPush(key);
      if (subscription == null) {
        _log.info('Web push subscription denied or unavailable');
        return false;
      }

      _log.info('Web push subscribed, registering with backend...');

      final client = _ref.read(msgrApiProvider);
      await client.post('/api/push/register', body: {
        'token': subscription,
        'platform': 'web_push',
        'device_name': 'Web Browser',
      });

      _log.info('Web push token registered!');
      _subscribed = true;
      return true;
    } catch (e) {
      _log.warning('Web push subscribe failed: $e');
      return false;
    }
  }
}

final webPushManagerProvider = Provider<WebPushManager>((ref) {
  final manager = WebPushManager(ref);

  ref.listen<SimpleAuthState>(simpleAuthProvider, (prev, next) {
    if (next.isLoggedIn && !next.isLoading && kIsWeb) {
      // VAPID public key — loaded from backend or hardcoded
      // We'll fetch it from a config endpoint
      _fetchVapidKeyAndInit(ref, manager);
    }
  }, fireImmediately: true);

  return manager;
});

Future<void> _fetchVapidKeyAndInit(Ref ref, WebPushManager manager) async {
  try {
    final client = ref.read(msgrApiProvider);
    final result = await client.getRaw('/api/push/vapid_key');
    final key = (result is Map) ? result['vapid_public_key'] as String? : null;
    if (key != null && key.isNotEmpty) {
      manager.setVapidKey(key);
      _log.info('VAPID key loaded, ready for subscription');
    }
  } catch (e) {
    _log.warning('Failed to fetch VAPID key: $e');
  }
}

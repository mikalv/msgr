// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

/// Check if notification permission is already granted.
bool isNotificationGranted() {
  try {
    return html.Notification.permission == 'granted';
  } catch (_) {
    return false;
  }
}

/// Subscribe to Web Push notifications via browser Push API.
/// Returns the subscription as a JSON string, or null if denied/unavailable.
Future<String?> subscribeToPush(String vapidPublicKey) async {
  try {
    print('[WebPush] Registering service worker...');
    // Register push SW — use the returned registration directly for subscription
    // (don't use navigator.serviceWorker.ready which may return Flutter's SW)
    final registration = await html.window.navigator.serviceWorker!
        .register('/push_sw.js');
    print('[WebPush] SW registered, waiting for active...');

    // Wait for SW to activate
    var attempts = 0;
    while (registration.active == null && attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 250));
      attempts++;
    }
    print('[WebPush] SW active=${ registration.active != null}, requesting permission...');

    // Request notification permission
    final permission = await html.Notification.requestPermission();
    print('[WebPush] Permission result: $permission');
    if (permission != 'granted') return null;

    // Convert VAPID public key from URL-safe base64 to Uint8List
    final applicationServerKey = _urlBase64ToUint8List(vapidPublicKey);

    // Subscribe to push manager
    final pushManager = js_util.getProperty(registration, 'pushManager');
    final subscribeOptions = js_util.jsify({
      'userVisibleOnly': true,
      'applicationServerKey': applicationServerKey,
    });

    final subscription = await js_util.promiseToFuture(
      js_util.callMethod(pushManager, 'subscribe', [subscribeOptions]),
    );

    // Extract subscription data
    final endpoint = js_util.getProperty(subscription, 'endpoint') as String;

    final p256dhBuffer = js_util.callMethod(subscription, 'getKey', ['p256dh']);
    final authBuffer = js_util.callMethod(subscription, 'getKey', ['auth']);

    if (p256dhBuffer == null || authBuffer == null) return null;

    final p256dh = _arrayBufferToBase64Url(p256dhBuffer);
    final auth = _arrayBufferToBase64Url(authBuffer);

    final result = jsonEncode({
      'endpoint': endpoint,
      'keys': {
        'p256dh': p256dh,
        'auth': auth,
      },
    });

    return result;
  } catch (e) {
    print('[WebPush] Subscribe failed: $e');
    return null;
  }
}

Uint8List _urlBase64ToUint8List(String base64String) {
  final padding = '=' * ((4 - base64String.length % 4) % 4);
  final b64 = (base64String + padding)
      .replaceAll('-', '+')
      .replaceAll('_', '/');
  return base64Decode(b64);
}

String _arrayBufferToBase64Url(dynamic arrayBuffer) {
  final bytes = Uint8List.view(arrayBuffer as ByteBuffer);
  return base64UrlEncode(bytes).replaceAll('=', '');
}

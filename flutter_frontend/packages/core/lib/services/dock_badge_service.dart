import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Controls macOS dock icon badge count and bounce animation.
///
/// On non-macOS platforms, all methods are no-ops.
class DockBadgeService {
  DockBadgeService._();
  static final instance = DockBadgeService._();

  static const _channel = MethodChannel('no.msgr/dock');

  /// Set the unread count badge on the dock icon. 0 clears it.
  Future<void> setBadge(int count) async {
    if (!_isMacOS) return;
    try {
      await _channel.invokeMethod('setBadge', {'count': count});
    } catch (_) {}
  }

  /// Bounce the dock icon until the user clicks the app.
  Future<void> bounce() async {
    if (!_isMacOS) return;
    try {
      await _channel.invokeMethod('bounce');
    } catch (_) {}
  }

  /// Cancel an ongoing bounce.
  Future<void> cancelBounce() async {
    if (!_isMacOS) return;
    try {
      await _channel.invokeMethod('cancelBounce');
    } catch (_) {}
  }

  bool get _isMacOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
}

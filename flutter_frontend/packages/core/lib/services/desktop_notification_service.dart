import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

// Conditional import: dart:io only available on native platforms
import 'desktop_notification_service_stub.dart'
    if (dart.library.io) 'desktop_notification_service_io.dart' as impl;

/// Service for showing native macOS desktop notifications via osascript.
///
/// On web, all methods are no-ops.
class DesktopNotificationService {
  DesktopNotificationService();

  static final _log = Logger('DesktopNotificationService');

  /// Global focus state, updated by the window manager listener in macos.dart.
  static bool isWindowFocused = true;

  /// Whether the app window is currently focused and visible.
  bool get isAppFocused => isWindowFocused;

  Future<void> showMessageNotification({
    required String title,
    required String body,
    required String channelId,
    bool playSound = true,
  }) async {
    if (kIsWeb) return;
    await impl.showNotification(title: title, body: body, playSound: playSound);
  }

  Future<void> showMentionNotification({
    required String channelName,
    required String senderName,
    required String body,
    required String channelId,
  }) async {
    await showMessageNotification(
      title: 'Mentioned in #$channelName',
      body: '$senderName: $body',
      channelId: channelId,
      playSound: true,
    );
  }
}

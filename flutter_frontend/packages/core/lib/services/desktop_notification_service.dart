import 'dart:io';

import 'package:logging/logging.dart';

/// Service for showing native macOS desktop notifications via osascript.
///
/// Uses `display notification` AppleScript command which requires no
/// additional packages or entitlements.
class DesktopNotificationService {
  DesktopNotificationService();

  static final _log = Logger('DesktopNotificationService');

  /// Global focus state, updated by the window manager listener in macos.dart.
  static bool isWindowFocused = true;

  /// Whether the app window is currently focused and visible.
  bool get isAppFocused => isWindowFocused;

  /// Show a macOS notification for a new message.
  ///
  /// [title] - Notification title (e.g. "#general" or "DM: Alice")
  /// [body] - Message content, truncated to 100 chars
  /// [channelId] - Channel ID for navigation on tap
  /// [playSound] - Whether to play the default notification sound
  Future<void> showMessageNotification({
    required String title,
    required String body,
    required String channelId,
    bool playSound = true,
  }) async {
    if (!Platform.isMacOS) return;

    final truncatedBody =
        body.length > 100 ? '${body.substring(0, 97)}...' : body;

    // Escape quotes and backslashes for AppleScript
    final escapedTitle =
        title.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
    final escapedBody =
        truncatedBody.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

    final soundClause = playSound ? ' sound name "default"' : '';

    final script =
        'display notification "$escapedBody" with title "$escapedTitle"$soundClause';

    try {
      final result = await Process.run('osascript', ['-e', script]);
      if (result.exitCode != 0) {
        _log.warning(
            'osascript notification failed (exit ${result.exitCode}): ${result.stderr}');
      } else {
        _log.fine('Notification shown: $title');
      }
    } catch (e) {
      _log.warning('Failed to show notification: $e');
    }
  }

  /// Show a mention notification. These are higher priority.
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

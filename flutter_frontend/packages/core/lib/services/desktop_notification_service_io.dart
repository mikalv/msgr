import 'dart:io';

import 'package:logging/logging.dart';

final _log = Logger('DesktopNotificationService');

/// Native implementation using osascript on macOS.
Future<void> showNotification({
  required String title,
  required String body,
  bool playSound = true,
}) async {
  if (!Platform.isMacOS) return;

  final truncatedBody =
      body.length > 100 ? '${body.substring(0, 97)}...' : body;

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

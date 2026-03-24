import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/desktop_notification_service.dart';

/// Singleton provider for the desktop notification service.
final desktopNotificationServiceProvider =
    Provider<DesktopNotificationService>((ref) {
  return DesktopNotificationService();
});

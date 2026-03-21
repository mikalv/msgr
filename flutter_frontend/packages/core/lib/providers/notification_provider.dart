import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/desktop_notification_service.dart';

/// Singleton provider for the desktop notification service.
final desktopNotificationServiceProvider =
    Provider<DesktopNotificationService>((ref) {
  final service = DesktopNotificationService();

  if (Platform.isMacOS) {
    // Focus observation is started in main.dart after WidgetsBinding is ready.
    // The service instance is shared via this provider.
  }

  return service;
});

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// Helper class for getting shared storage paths between apps
class SharedStorageHelper {
  /// App Group identifier for iOS
  static const String appGroupId = 'group.dev.meeh.messngr';

  /// Get the shared database directory path
  ///
  /// On iOS: Uses App Group container
  /// On Android: Uses getApplicationSupportDirectory (same for apps with same sharedUserId)
  /// On other platforms: Uses regular path
  static Future<String> getSharedDatabasePath() async {
    if (kIsWeb) {
      return 'web_db';
    }

    if (Platform.isIOS || Platform.isMacOS) {
      // On iOS/macOS, use App Group container
      // Note: This requires adding App Groups capability in Xcode
      // For now, we'll use a plugin like shared_preferences with App Groups
      // or path_provider_ios with App Groups support

      // TODO: Implement actual App Group path retrieval
      // This will require platform-specific code or a plugin that supports it
      // For now, fallback to regular directory
      final dir = await getApplicationSupportDirectory();
      return dir.path;
    } else if (Platform.isAndroid) {
      // On Android, apps with same sharedUserId share storage
      // Using getApplicationSupportDirectory will give shared path
      final dir = await getApplicationSupportDirectory();
      return dir.path;
    } else {
      // Desktop platforms
      final dir = await getApplicationSupportDirectory();
      return dir.path;
    }
  }

  /// Get shared preferences path (for keychain sharing on iOS)
  static Future<String> getSharedPreferencesPath() async {
    return getSharedDatabasePath();
  }
}

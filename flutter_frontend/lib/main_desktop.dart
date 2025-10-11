import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/desktop/linux.dart';
import 'package:messngr/desktop/macos.dart';
import 'package:messngr/desktop/windows.dart';
import 'package:window_manager/window_manager.dart';

Future<void> runDesktopApp() async {
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
      size: defaultDesktopWindowSize,
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      minimumSize: minimumDesktopWindowSize);
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  if (Platform.isMacOS) {
    return runApp(const MacOSApp());
  } else if (Platform.isWindows) {
    return runApp(const WindowsApp());
  } else if (Platform.isLinux) {
    return runApp(const LinuxApp());
  }
}

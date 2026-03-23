import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/desktop/linux.dart';
import 'package:messngr/desktop/macos.dart';
import 'package:messngr/desktop/windows.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

const _kWindowX = 'window_x';
const _kWindowY = 'window_y';
const _kWindowW = 'window_w';
const _kWindowH = 'window_h';

Future<void> runDesktopApp() async {
  await windowManager.ensureInitialized();

  // Restore saved window bounds, or use defaults
  final prefs = await SharedPreferences.getInstance();
  final savedW = prefs.getDouble(_kWindowW);
  final savedH = prefs.getDouble(_kWindowH);
  final savedX = prefs.getDouble(_kWindowX);
  final savedY = prefs.getDouble(_kWindowY);

  final hasSavedBounds = savedW != null && savedH != null;
  final size = hasSavedBounds
      ? Size(savedW, savedH)
      : defaultDesktopWindowSize;

  WindowOptions windowOptions = WindowOptions(
    size: hasSavedBounds ? size : defaultDesktopWindowSize,
    center: !hasSavedBounds,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    minimumSize: minimumDesktopWindowSize,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    // Restore saved bounds AFTER the window is ready — avoids framework reset
    if (hasSavedBounds) {
      await windowManager.setSize(size);
      if (savedX != null && savedY != null) {
        await windowManager.setPosition(Offset(savedX, savedY));
      }
    }
    await windowManager.show();
    await windowManager.focus();
  });

  if (Platform.isMacOS || Platform.isIOS) {
    return runApp(const MacOSApp());
  } else if (Platform.isWindows) {
    return runApp(const WindowsApp());
  } else if (Platform.isLinux) {
    return runApp(const LinuxApp());
  }
}

/// Save current window bounds to SharedPreferences.
/// Call from WindowListener callbacks (onWindowMoved, onWindowResized).
Future<void> saveWindowBounds() async {
  try {
    final position = await windowManager.getPosition();
    final size = await windowManager.getSize();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kWindowX, position.dx);
    await prefs.setDouble(_kWindowY, position.dy);
    await prefs.setDouble(_kWindowW, size.width);
    await prefs.setDouble(_kWindowH, size.height);
  } catch (_) {
    // Best-effort — don't crash on save failure
  }
}

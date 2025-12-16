import 'dart:io' show Platform, exit;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:core/app/bootstrap/bootstrapper.dart';
import 'package:core/desktop/web.dart';
import 'package:core/main_desktop.dart';
import 'package:core/main_mobile.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:logging/logging.dart';

/// Msgr Personal - For private and family conversations
Future<void> main() async {
  const bootstrapper = Bootstrapper();
  await bootstrapper.initialize();

  // Set app mode to personal for filtering
  // This will be used by providers to filter personal/family content
  Logger.root.info('Starting Msgr Personal (Bundle: dev.meeh.messngr.personal)');

  if (kIsWeb) {
    Logger.root.info('Is Web');
    runApp(const WebApp());
    return;
  }

  if (Platform.isAndroid || Platform.isIOS || Platform.isFuchsia) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    runApp(const OverlaySupport.global(child: MessngrApp()));
  } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    // Desktop
    runDesktopApp();
  } else {
    Logger.root.severe('Platform not supported');
    exit(-1);
  }
}

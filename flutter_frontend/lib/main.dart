import 'dart:io' show Platform, exit;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:messngr/app/bootstrap/bootstrapper.dart';
import 'package:core/mobile/ios.dart';
import 'package:messngr/desktop/web.dart';
import 'package:messngr/main_desktop.dart';
import 'package:messngr/main_mobile.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:logging/logging.dart';

Future<void> main() async {
  const bootstrapper = Bootstrapper();
  await bootstrapper.initialize();

  if (kIsWeb) {
    // IOSApp = shared AppShell entry (works for web, iOS, any non-windowed platform)
    // WebApp/MessngrApp = old single-user/personal mode UI (reserved for future E2EE personal mode)
    runApp(const IOSApp());
    return;
  }

  if (Platform.isIOS) {
    runApp(const IOSApp());
  } else if (Platform.isAndroid || Platform.isFuchsia) {
    // MessngrApp = old single-user/personal mode UI (reserved for future E2EE personal mode)
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    runApp(const OverlaySupport.global(child: MessngrApp()));
  } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    runDesktopApp();
  } else {
    Logger.root.severe('What the fuck, don\'t get the platform...');
    exit(-1);
  }
}

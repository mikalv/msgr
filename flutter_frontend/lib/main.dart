import 'dart:io' show Platform, exit;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:messngr/app/bootstrap/bootstrapper.dart';
import 'package:messngr/desktop/web.dart';
import 'package:messngr/main_desktop.dart';
import 'package:messngr/main_mobile.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:logging/logging.dart';

Future<void> main() async {
  const bootstrapper = Bootstrapper();
  await bootstrapper.initialize();

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
    Logger.root.severe('What the fuck, don\'t get the platform...');
    exit(-1);
  }
}

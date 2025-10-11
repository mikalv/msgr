import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:logging/logging.dart';
import 'package:messngr/desktop/web.dart';
import 'package:messngr/main_desktop.dart';
import 'package:messngr/main_mobile.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/utils/device_info_impl.dart';
import 'package:messngr/utils/secure_store_impl.dart';
import 'package:messngr/utils/shared_preferences_impl.dart';
import 'package:overlay_support/overlay_support.dart';
import 'dart:io' show Platform, exit;

void checkNetwork() async {
  final List<ConnectivityResult> connectivityResult =
      await (Connectivity().checkConnectivity());

  StreamSubscription<List<ConnectivityResult>> subscription = Connectivity()
      .onConnectivityChanged
      .listen((List<ConnectivityResult> result) {
    // Received changes in available connectivity types!
    // TODO: Forward this to libmsgr
  });
}

Future<void> main() async {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((record) {
    print(
      '[${record.loggerName}] ${record.level.name} ${record.time}: '
      '${record.message}',
    );
  });
  AppNavigation.instance;
  LibMsgr().secureStorage = SecureStore();

  //await LibMsgr().resetEverything(true);
  LibMsgr().deviceInfoInstance = DeviceInfoImpl();
  LibMsgr().sharedPreferences = SharedPreferencesImpl();
  await LibMsgr().bootstrapLibrary();

  final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();

  binding.renderView.automaticSystemUiAdjustment = false;

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

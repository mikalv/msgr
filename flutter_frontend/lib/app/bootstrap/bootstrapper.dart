import 'package:flutter/widgets.dart';
import 'package:messngr/app/bootstrap/device_context_bootstrap.dart';
import 'package:messngr/app/bootstrap/libmsgr_bootstrap.dart';
import 'package:messngr/app/bootstrap/logging_bootstrap.dart';
import 'package:messngr/config/AppNavigation.dart';

/// Handles the one-time initialization required before any Flutter widgets are
/// rendered.
class Bootstrapper {
  const Bootstrapper();

  Future<void> initialize() async {
    bootstrapLogging();
    AppNavigation.instance;

    await bootstrapLibMsgr();
    final deviceContextBootstrapper = DeviceContextBootstrapper.create();
    await deviceContextBootstrapper.initialize();

    final binding = WidgetsFlutterBinding.ensureInitialized();
    binding.renderView.automaticSystemUiAdjustment = false;
  }
}

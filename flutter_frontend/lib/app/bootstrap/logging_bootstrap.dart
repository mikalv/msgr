import 'dart:async';

import 'package:logging/logging.dart';
import 'package:messngr/services/logging/open_observe_log_client.dart';

/// Configures the global [Logger] instance used by the application.
///
/// This extracts the logging bootstrapping from `main.dart` so it can be reused
/// by other entrypoints (desktop, web, tests) once the new architecture plan is
/// rolled out.
void bootstrapLogging({
  Level level = Level.FINE,
  OpenObserveLogClient? Function()? createLogClient,
}) {
  Logger.root.level = level;
  final openObserveClient =
      createLogClient != null ? createLogClient() : OpenObserveLogClient.maybeCreate();

  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print('[${record.loggerName}] ${record.level.name} ${record.time}: '
        '${record.message}');
    if (openObserveClient != null) {
      unawaited(openObserveClient.send(record));
    }
  });
}

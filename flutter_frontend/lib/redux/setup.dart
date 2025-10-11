// ignore_for_file: prefer_spread_collections, implicit_call_tearoffs, dead_code, unused_element

import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/redux/app/app_middleware.dart';
import 'package:messngr/redux/app_reducer.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/authentication/auth_middleware.dart';
import 'package:messngr/redux/conversation_room/conversation_room_middleware.dart';
import 'package:messngr/redux/invitation/invitation_middleware.dart';
import 'package:messngr/redux/message/message_middleware.dart';
import 'package:messngr/redux/profile/profile_middleware.dart';
import 'package:messngr/utils/redux_logging.dart';
import 'package:messngr/utils/redux_thunk.dart';
import 'package:redux/redux.dart';
import 'package:redux_dev_tools/redux_dev_tools.dart';
import 'package:redux_persist/redux_persist.dart';
import 'package:redux_remote_devtools/redux_remote_devtools.dart';
import 'package:messngr/redux/state_storage/storage.dart';

class ReduxSetup {
  static final Logger _log = Logger('ReduxSetup');

  static Future<Store<AppState>> getReduxStore() async {
    final persistor = Persistor<AppState>(
      storage: getReduxPersistStorage(_log),
      serializer: JsonSerializer<AppState>(
          AppState.fromJson), // Or use other serializers
      debug: kReduxPersistorInDebugMode,
      throttleDuration:
          const Duration(seconds: minimumSecondsBetweenFlushStateToDisk),
    );

    AppState? initialState;
    try {
      // Try load initial state from disk
      initialState = await persistor.load();
    } catch (e) {
      // Fallback to default state
      _log.severe('Error loading state from disk: $e');
      initialState = AppState.initial();
    }

    String onlyLogActionFormatter<State>(
      State state,
      dynamic action,
      DateTime timestamp,
    ) {
      return '{Action: $action}';
    }

    String silentSomeEventsFormatter<State>(
      State state,
      dynamic action,
      DateTime timestamp,
    ) {
      return 'Action: $action\nState: $state\nTimestamp: $timestamp';
    }

    // It's possible to remove the formatter to see more state. But in general
    // this is waaay too much noise in the log.
    // Alternative formatters:
    //  - LoggingMiddleware.singleLineFormatter
    //  - LoggingMiddleware.multiLineFormatter
    final loggerMiddleware = LoggingMiddleware(
        logger: _log,
        formatter:
            LoggingMiddleware.multiLineFormatter); //onlyLogActionFormatter);

    /*_log.onRecord
        .where((record) => record.loggerName == _log.name)
        .listen((loggingMiddlewareRecord) => print(loggingMiddlewareRecord));*/

    final List<Middleware<AppState>> middlewares = []
      ..addAll(createAuthenticationMiddleware())
      ..addAll(createRoomsMiddlewares())
      ..addAll(createConversationsMiddlewares())
      ..addAll(createProfileMiddleware())
      ..addAll(createMessageMiddlewares())
      ..addAll(createInvitationMiddlewares())
      ..addAll(createAppMiddleware())
      ..add(thunkMiddleware)
      ..add(persistor.createMiddleware())
      ..add(loggerMiddleware);

    if (kReduxUseWebTools) {
      final remoteDevtools = RemoteDevToolsMiddleware('127.0.0.1:8000');
      final store = DevToolsStore<AppState>(mainReducer,
          initialState: initialState!,
          middleware: middlewares..add(remoteDevtools));
      remoteDevtools.store = store;
      remoteDevtools.connect();
      return store;
    } else {
      final store = Store<AppState>(mainReducer,
          initialState: initialState!, middleware: middlewares);
      return store;
    }
  }
}

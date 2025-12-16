import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

class MsgrNavigatorObserver extends NavigatorObserver {
  final Logger _log = Logger('MsgrNavigatorObserver');
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log.info('Pushed route: ${route.settings}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log.info('Popped route: ${route.settings}');
  }
}

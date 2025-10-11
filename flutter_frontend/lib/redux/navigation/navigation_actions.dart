import 'package:flutter/material.dart';
import 'package:redux/redux.dart';

class NavigateToNewRouteAction {
  final String route;
  final Map<String, dynamic> kRouteArgs;
  final BuildContext? context;

  NavigateToNewRouteAction(
      {required this.route, this.kRouteArgs = const {}, this.context});

  @override
  String toString() {
    return 'NavigateToNewRouteAction{route: $route, kRouteArgs: $kRouteArgs}';
  }
}

class NavigateShellToNewRouteAction {
  final String route;
  final String? conversationID;
  final String? roomID;
  final bool kRouteDoPopInstead;
  final bool kUsePush;
  final Map<String, dynamic> kRouteArgs;
  final BuildContext? context;

  NavigateShellToNewRouteAction(
      {required this.route,
      this.conversationID,
      this.roomID,
      this.kRouteDoPopInstead = false,
      this.kUsePush = true,
      this.kRouteArgs = const {},
      this.context});

  @override
  String toString() {
    return 'NavigateShellToNewRouteAction{route: $route, kRouteArgs: $kRouteArgs, kRouteDoPopInstead: $kRouteDoPopInstead, '
        'conversationID: $conversationID, roomID: $roomID}';
  }
}

triggerNewRouteNavigation(Store store, String path) async {
  await store.dispatch(NavigateToNewRouteAction(route: path));
}

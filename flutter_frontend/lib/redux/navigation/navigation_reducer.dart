// ignore_for_file: implicit_call_tearoffs

import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/redux/navigation/navigation_actions.dart';
import 'package:redux/redux.dart';

Reducer<String> currentRouteReducer = combineReducers([
  TypedReducer<String, NavigateToNewRouteAction>((currentRoute, action) {
    if (currentRoute != action.route) {
      AppNavigation.router.push(Uri(path: action.route, queryParameters: action.kRouteArgs).toString());
    }
    return action.route;
  }),
  TypedReducer<String, NavigateShellToNewRouteAction>((currentRoute, action) {
    if (action.kRouteDoPopInstead) {
      AppNavigation.router.pop();
    } else {
      if (action.kUsePush) {
        AppNavigation.router.push(Uri(path: action.route, queryParameters: action.kRouteArgs).toString());
      } else {
        AppNavigation.router.go(Uri(path: action.route, queryParameters: action.kRouteArgs).toString());
      }
    }
    return action.route;
  }),
]);

// ignore_for_file: implicit_call_tearoffs

import 'package:messngr/redux/app/app_actions.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:redux/redux.dart';

List<Middleware<AppState>> createAppMiddleware() {
  return [
    TypedMiddleware<AppState, PersistData>(_persistDataFn()),
    TypedMiddleware<AppState, PersistPrefs>(_persistPreferencesFn()),
  ];
}

Middleware<AppState> _persistPreferencesFn() {
  return (Store<AppState> store, dynamic dynamicAction, NextDispatcher next) {
    final action = dynamicAction as PersistPrefs?;
    next(action);
  };
}

Middleware<AppState> _persistDataFn() {
  return (Store<AppState> store, dynamic dynamicAction, NextDispatcher next) {
    final action = dynamicAction as PersistData?;
    next(action);
  };
}

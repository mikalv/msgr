// ignore_for_file: implicit_call_tearoffs

import 'package:messngr/redux/ui/ui_actions.dart';
import 'package:messngr/redux/ui/ui_state.dart';
import 'package:redux/redux.dart';

Reducer<UiState> uiReducersCombined = combineReducers([
  TypedReducer<UiState, OnWindowResize>(_onWindowResize),
  TypedReducer<UiState, OnWindowMove>(_onWindowMove),
  TypedReducer<UiState, OnWindowBlur>(_onWindowBlur),
  TypedReducer<UiState, OnWindowFocus>(_onWindowFocus),
]);

UiState _onWindowResize(UiState state, OnWindowResize action) {
  return UiState(
      windowSize: action.windowSize,
      windowPosition: state.windowPosition,
      isLoading: state.isLoading);
}

UiState _onWindowMove(UiState state, OnWindowMove action) {
  return UiState(
      isLoading: false,
      windowPosition: action.windowPosition,
      windowSize: state.windowSize);
}

UiState _onWindowBlur(UiState state, OnWindowBlur action) {
  return UiState(
      isLoading: false,
      windowPosition: state.windowPosition,
      windowSize: state.windowSize,
      hasFocus: false);
}

UiState _onWindowFocus(UiState state, OnWindowFocus action) {
  return UiState(
      isLoading: false,
      windowPosition: state.windowPosition,
      windowSize: state.windowSize,
      hasFocus: true);
}

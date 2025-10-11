// ignore_for_file: implicit_call_tearoffs

import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/authentication/auth_actions.dart';
import 'package:messngr/redux/team_state.dart';
import 'package:redux/redux.dart';

Reducer<AppState> appReducersCombined = combineReducers([
  TypedReducer<AppState, OnWebSocketConnectedAction>(_onWebSocketConnected),
  TypedReducer<AppState, OnBootstrapAction>(_onBootstrapTeam),
]);

/// This reducer is used to update the team state when the app is bootstrapped
/// with the team data.
///
/// Usually this is handled by the [_onBootstrapTeam] function. However it does not
/// have access to the [AppState] object, so this reducer is used to update the
///  [TeamState] object within the [AppState] object.
/// (We need to update the [TeamState] based upon data from [AuthState])
AppState _onBootstrapTeam(AppState state, OnBootstrapAction action) {
  TeamState teamState = TeamState(
      selectedTeam: state.authState.currentTeam,
      conversations: action.conversations,
      rooms: action.rooms,
      profiles: action.profiles);
  return state.copyWith(
      error: null,
      currentProfile: state.currentProfile,
      authState: state.authState,
      uiState: state.uiState,
      teamState: teamState,
      currentRoute: state.currentRoute);
}

AppState _onWebSocketConnected(
    AppState state, OnWebSocketConnectedAction action) {
  TeamState teamState = TeamState(selectedTeam: state.authState.currentTeam);
  return state.copyWith(
      error: null,
      currentProfile: state.currentProfile,
      authState: state.authState,
      uiState: state.uiState,
      teamState: teamState,
      currentRoute: state.currentRoute);
}

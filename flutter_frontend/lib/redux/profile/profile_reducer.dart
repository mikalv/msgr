// ignore_for_file: implicit_call_tearoffs

import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/authentication/auth_state.dart';
import 'package:messngr/redux/profile/profile_actions.dart';
import 'package:redux/redux.dart';

Reducer<AppState> profileReducersCombined = combineReducers([
  TypedReducer<AppState, OnCreateProfileSuccessAction>(
      _onCreatedProfileReducer),
  TypedReducer<AppState, OnCreateProfileFailureAction>(
      _onProfileCreateFailureReducer),
]);

AppState _onCreatedProfileReducer(
    AppState state, OnCreateProfileSuccessAction action) {
  final auth = AuthState(
      kIsLoggedIn: state.authState.isLoggedIn,
      currentUser: state.authState.currentUser,
      currentProfile: action.profile,
      currentTeam: state.authState.currentTeam,
      currentTeamName: state.authState.currentTeamName,
      teamAccessToken: state.authState.teamAccessToken,
      teams: state.authState.teams,
      isLoading: state.authState.isLoading,
      pendingEmail: state.authState.pendingEmail,
      pendingMsisdn: state.authState.pendingMsisdn,
      pendingTeam: state.authState.pendingTeam,
      pendingChallengeId: state.authState.pendingChallengeId,
      pendingChannel: state.authState.pendingChannel,
      pendingTargetHint: state.authState.pendingTargetHint,
      pendingDebugCode: state.authState.pendingDebugCode,
      pendingChallengeExpiresAt: state.authState.pendingChallengeExpiresAt);
  return AppState(
      authState: auth,
      teamState: state.teamState,
      currentRoute: state.currentRoute,
      currentProfile: action.profile,
      uiState: state.uiState,
      error: state.error);
}

AppState _onProfileCreateFailureReducer(
    AppState state, OnCreateProfileFailureAction action) {
  return AppState(
      authState: state.authState,
      teamState: state.teamState,
      currentRoute: state.currentRoute,
      currentProfile: null,
      uiState: state.uiState,
      error: state.error);
}

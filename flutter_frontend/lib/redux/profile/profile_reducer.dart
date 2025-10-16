// ignore_for_file: implicit_call_tearoffs

import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/authentication/auth_state.dart';
import 'package:messngr/redux/profile/profile_actions.dart';
import 'package:messngr/redux/team_state.dart';
import 'package:redux/redux.dart';

Reducer<AppState> profileReducersCombined = combineReducers([
  TypedReducer<AppState, OnCreateProfileSuccessAction>(
      _onCreatedProfileReducer),
  TypedReducer<AppState, OnCreateProfileFailureAction>(
      _onProfileCreateFailureReducer),
  TypedReducer<AppState, RefreshProfilesSuccessAction>(
      _onRefreshProfilesSuccess),
  TypedReducer<AppState, SwitchProfileSuccessAction>(
      _onSwitchProfileSuccess),
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

AppState _onRefreshProfilesSuccess(
    AppState state, RefreshProfilesSuccessAction action) {
  final profiles = action.profiles;
  Profile? activeProfile;
  for (final profile in profiles) {
    if (profile.isActive) {
      activeProfile = profile;
      break;
    }
  }

  final teamState = state.teamState?.copyWith(profiles: profiles) ??
      TeamState(selectedTeam: state.authState.currentTeam, profiles: profiles);

  final auth = AuthState(
      kIsLoggedIn: state.authState.isLoggedIn,
      currentUser: state.authState.currentUser,
      currentProfile: activeProfile ?? state.authState.currentProfile,
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
      pendingChallengeExpiresAt: state.authState.pendingChallengeExpiresAt,
      pendingDisplayName: state.authState.pendingDisplayName);

  return AppState(
      authState: auth,
      teamState: teamState,
      currentRoute: state.currentRoute,
      currentProfile: activeProfile ?? state.currentProfile,
      uiState: state.uiState,
      error: state.error);
}

AppState _onSwitchProfileSuccess(
    AppState state, SwitchProfileSuccessAction action) {
  final updatedProfiles = (state.teamState?.profiles ?? const <Profile>[])
      .map((profile) => profile.id == action.profile.id
          ? action.profile.copyWith(isActive: true)
          : profile.copyWith(isActive: false))
      .toList(growable: false);

  final teamState = state.teamState?.copyWith(profiles: updatedProfiles) ??
      TeamState(selectedTeam: state.authState.currentTeam, profiles: updatedProfiles);

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
      pendingChallengeExpiresAt: state.authState.pendingChallengeExpiresAt,
      pendingDisplayName: state.authState.pendingDisplayName);

  return AppState(
      authState: auth,
      teamState: teamState,
      currentRoute: state.currentRoute,
      currentProfile: action.profile,
      uiState: state.uiState,
      error: state.error);
}

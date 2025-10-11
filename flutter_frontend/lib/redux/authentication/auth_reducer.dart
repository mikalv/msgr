// ignore_for_file: implicit_call_tearoffs

import 'package:libmsgr/libmsgr.dart';

import 'auth_actions.dart';
import 'auth_state.dart';
import 'package:redux/redux.dart';

final authReducers = <AuthState Function(AuthState, dynamic)>[
  TypedReducer<AuthState, OnAuthenticatedAction>(_onAuthenticated),
  TypedReducer<AuthState, OnAuthenticatedWithTeamAction>(
      _onAuthenticatedWithTeam),
  TypedReducer<AuthState, OnAuthFailureAction>(_onAuthenticatedFailure),
  TypedReducer<AuthState, OnLogoutSuccessAction>(_onLogout),
  TypedReducer<AuthState, OnListMyTeamsResponseAction>(_onMyTeamsList),
  TypedReducer<AuthState, OnCreateTeamSuccessAction>(_onCreateTeam),
  TypedReducer<AuthState, RequestCodeMsisdnAction>(_onMsisdnCodeRequest),
  TypedReducer<AuthState, RequestCodeEmailAction>(_onEmailCodeRequest),
];

AuthState _onMsisdnCodeRequest(
    AuthState state, RequestCodeMsisdnAction action) {
  return AuthState(
      kIsLoggedIn: false,
      currentUser: null,
      currentProfile: null,
      teams: [],
      isLoading: false,
      pendingMsisdn: action.msisdn);
}

AuthState _onEmailCodeRequest(AuthState state, RequestCodeEmailAction action) {
  return AuthState(
      kIsLoggedIn: false,
      currentUser: null,
      currentProfile: null,
      teams: [],
      isLoading: false,
      pendingEmail: action.email);
}

AuthState _onAuthenticated(AuthState state, OnAuthenticatedAction action) {
  return AuthState(
      kIsLoggedIn: true,
      currentUser: action.user,
      currentProfile: state.currentProfile,
      currentTeam: state.currentTeam,
      teamAccessToken: state.teamAccessToken,
      teams: state.teams,
      isLoading: false,
      pendingTeam: null, // reset all pending
      pendingEmail: null,
      pendingMsisdn: null);
}

AuthState _onCreateTeam(AuthState state, OnCreateTeamSuccessAction action) {
  return AuthState(
      kIsLoggedIn: true,
      currentUser: state.currentUser,
      currentProfile: state.currentProfile,
      currentTeam: action.team,
      teamAccessToken: state.teamAccessToken,
      teams: state.teams,
      isLoading: false,
      currentTeamName: action.teamName);
}

AuthState _onMyTeamsList(AuthState state, OnListMyTeamsResponseAction action) {
  return AuthState(
      kIsLoggedIn: true,
      currentUser: state.currentUser,
      currentProfile: state.currentProfile,
      teams: action.teams,
      isLoading: false,
      pendingEmail: null, // reset all pending
      pendingMsisdn: null);
}

AuthState _onAuthenticatedWithTeam(
    AuthState state, OnAuthenticatedWithTeamAction action) {
  Team? team;
  // If currentTeam isn't set, try retrive it via currentTeamName and teams.
  if (state.currentTeam == null) {
    team = state.teams.where((t) => t.name == action.teamName).first;
  } else {
    team = state.currentTeam;
  }
  return AuthState(
      kIsLoggedIn: true,
      currentUser: state.currentUser,
      currentProfile: action.profile,
      currentTeamName: action.teamName,
      currentTeam: team,
      teamAccessToken: action.teamAccessToken,
      teams: state.teams,
      isLoading: false,
      pendingTeam: null, // reset all pending
      pendingEmail: null,
      pendingMsisdn: null);
}

AuthState _onAuthenticatedFailure(AuthState state, OnAuthFailureAction action) {
  return AuthState(
      kIsLoggedIn: false,
      currentUser: null,
      currentProfile: null,
      teams: [],
      isLoading: false,
      pendingTeam: null, // reset all pending
      pendingEmail: null,
      pendingMsisdn: null);
}

AuthState _onLogout(AuthState state, OnLogoutSuccessAction action) {
  // TODO: This is done so that backend won't crash due to multiple users per
  // TODO: one device (which is an ID, and cryptographic keys)
  // TODO: Refactor backend to accept many-to-many or find a better solution
  // TODO: on the deviceId/keys here..
  LibMsgr().resetEverything(true);
  return AuthState(
      kIsLoggedIn: false,
      currentUser: null,
      currentProfile: null,
      teams: [],
      isLoading: false,
      pendingTeam: null, // reset all pending
      pendingEmail: null,
      pendingMsisdn: null);
}

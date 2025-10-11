// ignore_for_file: implicit_call_tearoffs

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:logging/logging.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/authentication/auth_actions.dart';
import 'package:messngr/redux/navigation/navigation_actions.dart';
import 'package:redux/redux.dart';
// TODO: Refactor RegistrationService out of this file
import 'package:libmsgr/src/registration_service.dart';

final Logger _log = Logger('AuthenticationMiddlewares');

/// Authentication Middleware
/// RequestCodeMsisdnAction / RequestCodeEmailAction: Request login code to auth user
/// LogInMsisdnAction / LogInEmailAction: submits identifier and code to login
/// LogOut: Logging user out
/// ListMyTeamsRequestAction: list teams user is member of
/// CreateTeamRequestAction: creates a new team
/// SelectAndAuthWithTeamAction: user logs into a team and get a teamAccessToken
/// VerifyAuthStateAction: Verify if user is logged in

List<Middleware<AppState>> createAuthenticationMiddleware() {
  return [
    TypedMiddleware<AppState, VerifyAuthStateAction>(_verifyAuthState()),
    TypedMiddleware<AppState, OpenWebsocketIfNotAlready>(_openWebsocket()),
    TypedMiddleware<AppState, OnWebSocketConnectedAction>(
        _onWebSocketConnected()),
    TypedMiddleware<AppState, RequestCodeMsisdnAction>(
        _authRequestCodeMsisdn()),
    TypedMiddleware<AppState, RequestCodeEmailAction>(_authRequestCodeEmail()),
    TypedMiddleware<AppState, LogInMsisdnAction>(_authLoginMsisdn()),
    TypedMiddleware<AppState, LogInEmailAction>(_authLoginEmail()),
    TypedMiddleware<AppState, LogOutAction>(_authLogout()),
    TypedMiddleware<AppState, ListMyTeamsRequestAction>(_listMyTeams()),
    TypedMiddleware<AppState, CreateTeamRequestAction>(_createNewTeam()),
    TypedMiddleware<AppState, SelectAndAuthWithTeamAction>(_selectTeam()),
    TypedMiddleware<AppState, OnAuthenticatedWithTeamAction>(
        _onAuthenticatedWithTeam())
  ];
}

void Function(
  Store<AppState> store,
  VerifyAuthStateAction action,
  NextDispatcher next,
) _verifyAuthState() {
  return (store, action, next) {
    next(action);
    if (store.state.authState.teamAccessToken != null) {
      store.dispatch(SelectAndAuthWithTeamAction(
          teamName: store.state.authState.currentTeamName!));
    }
  };
}

void Function(Store<AppState> store, OnWebSocketConnectedAction action,
    NextDispatcher next) _onWebSocketConnected() {
  return (store, action, next) async {
    next(action);
    final RepositoryFactory repositoryFactory = RepositoryFactory();
    TeamRepositories repos = repositoryFactory
        .getRepositories(store.state.authState.currentTeamName!);
    for (var room in repos.roomRepository.items) {
      LibMsgr().getWebsocketConnection()?.joinChannel(
          'room:${store.state.authState.currentTeamName}.${room.id}');
    }
  };
}

void Function(Store<AppState> store, OnAuthenticatedWithTeamAction action,
    NextDispatcher next) _onAuthenticatedWithTeam() {
  return (store, action, next) async {
    next(action);
    if (action.nextAction == 'create_profile') {
      store.dispatch(
          NavigateToNewRouteAction(route: AppNavigation.createProfilePath));
    } else {
      store.dispatch(OpenWebsocketIfNotAlready());
      store.dispatch(NavigateShellToNewRouteAction(
          route: AppNavigation.dashboardPath, kUsePush: false));
    }
  };
}

void Function(
  Store<AppState> store,
  OpenWebsocketIfNotAlready action,
  NextDispatcher next,
) _openWebsocket() {
  return (store, action, next) async {
    next(action);

    if (store.state.authState.currentUser != null &&
        store.state.authState.currentTeamName != null) {
      _log.info('Connecting to websocket');
      await LibMsgr().connectWebsocket(
          store.state.authState.currentUser!.uid,
          store.state.authState.currentTeamName!,
          store.state.authState.teamAccessToken!,
          store.dispatch);

      LibMsgr().currentUserID = store.state.authState.currentUser!.uid;
      final wsConn = LibMsgr().getWebsocketConnection();
      if (wsConn != null && wsConn.isConnected() == false) {
        _log.warning('Websocket not connected!!!!!!!!!!!!!!!!!!!!!!!!!!');
        store.dispatch(
            OnWebsocketConnectionFailedAction('Websocket not connected'));
      } else {
        store.dispatch(OnWebSocketConnectedAction());
      }
    } else {
      _log.warning('User not logged in yet.');
    }
  };
}

void Function(
  Store<AppState> store,
  SelectAndAuthWithTeamAction action,
  NextDispatcher next,
) _selectTeam() {
  return (store, action, next) async {
    next(action);
    // TODO: Calling RegistrationService service directly is not good. Refactor this.
    final data = await RegistrationService().selectTeam(
        action.teamName, store.state.authState.currentUser!.accessToken);
    if (data?['next_action'] == 'create_profile') {
      //
      store.dispatch(OnAuthenticatedWithTeamAction(
          teamName: data?['teamName'],
          nextAction: data?['next_action'],
          teamAccessToken: data?['teamAccessToken'],
          profile: null));
    } else {
      Profile profile = Profile.fromJson(data?['profile']);
      store.dispatch(OnAuthenticatedWithTeamAction(
          teamName: data?['teamName'],
          nextAction: data?['next_action'],
          teamAccessToken: data?['teamAccessToken'],
          profile: profile));
    }
  };
}

void Function(
  Store<AppState> store,
  dynamic action,
  NextDispatcher next,
) _authLogout() {
  return (store, action, next) async {
    next(action);
    store.dispatch(OnLogoutSuccessAction());
    store.dispatch(NavigateToNewRouteAction(route: AppNavigation.welcomePath));
    /*try {
      await authRepository.logOut();
      cancelAllSubscriptions();
      store.dispatch(OnLogoutSuccess());
    } catch (e) {
      Logger.w("Failed logout", e: e);
      store.dispatch(OnLogoutFail(e));
    }*/
  };
}

void Function(
  Store<AppState> store,
  CreateTeamRequestAction action,
  NextDispatcher next,
) _createNewTeam() {
  return (store, action, next) async {
    next(action);
    // TODO: Calling RegistrationService service directly is not good. Refactor this.
    final Team? result = await RegistrationService().createNewTeam(
        action.teamName,
        action.teamDesc,
        store.state.authState.currentUser!.accessToken);
    if (result != null) {
      store.dispatch(OnCreateTeamSuccessAction(
          teamName: result.name, teamID: result.id, team: result));
      store.dispatch(SelectAndAuthWithTeamAction(teamName: result.name));
    } else {
      store.dispatch(OnCreateTeamFailureAction(
          teamName: action.teamName, error: 'Error creating new team'));
    }
    //store.dispatch(OnListMyTeamsResponseAction(teams: teams));
  };
}

void Function(
  Store<AppState> store,
  ListMyTeamsRequestAction action,
  NextDispatcher next,
) _listMyTeams() {
  return (store, action, next) async {
    next(action);
    // TODO: Calling RegistrationService service directly is not good. Refactor this.
    final teams = await RegistrationService().listMyTeams(action.accessToken);
    action.completer.complete(teams);
    store.dispatch(OnListMyTeamsResponseAction(teams: teams));
  };
}

void Function(
  Store<AppState> store,
  dynamic action,
  NextDispatcher next,
) _authRequestCodeEmail() {
  return (store, action, next) async {
    next(action);
    try {
      // TODO: Calling RegistrationService service directly is not good. Refactor this.
      final challenge =
          await RegistrationService().requestForSignInCodeEmail(action.email);
      if (challenge != null) {
        store.dispatch(
            ServerRequestCodeFromUserAction(channel: 'email', challenge: challenge));
        action.completer.complete(challenge);
      } else {
        action.completer.completeError('Unable to request code');
      }
    } on PlatformException catch (e) {
      action.completer.completeError(e);
    }
  };
}

void Function(
  Store<AppState> store,
  dynamic action,
  NextDispatcher next,
) _authRequestCodeMsisdn() {
  return (store, action, next) async {
    next(action);
    try {
      // TODO: Calling RegistrationService service directly is not good. Refactor this.
      final challenge =
          await RegistrationService().requestForSignInCodeMsisdn(action.msisdn);
      if (challenge != null) {
        store.dispatch(
            ServerRequestCodeFromUserAction(channel: 'phone', challenge: challenge));
        action.completer.complete(challenge);
      } else {
        action.completer.completeError('Unable to request code');
      }
    } on PlatformException catch (e) {
      action.completer.completeError(e);
    }
  };
}

void Function(
  Store<AppState> store,
  dynamic action,
  NextDispatcher next,
) _authLoginMsisdn() {
  return (store, action, next) async {
    next(action);
    try {
      // TODO: Calling RegistrationService service directly is not good. Refactor this.
      final challengeId = store.state.authState.pendingChallengeId;
      if (challengeId == null) {
        action.completer.completeError('No active challenge.');
        return;
      }

      final user = await RegistrationService().submitMsisdnCodeForToken(
          challengeId: challengeId,
          code: action.code,
          displayName: store.state.authState.pendingDisplayName);
      if (user != null) {
        store.dispatch(OnAuthenticatedAction(user: user));

        final completer = Completer();
        completer.future.then((val) {
          store.dispatch(
              NavigateToNewRouteAction(route: AppNavigation.selectTeamPath));
        }).catchError((error) {
          debugPrint(error);
        });
        store.dispatch(ListMyTeamsRequestAction(
            accessToken: user.accessToken, completer: completer));
        action.completer.complete(user);
      } else {
        action.completer.completeError('Login failed.');
      }
    } on PlatformException catch (e) {
      action.completer.completeError(e);
    }
  };
}

void Function(
  Store<AppState> store,
  dynamic action,
  NextDispatcher next,
) _authLoginEmail() {
  return (store, action, next) async {
    next(action);
    try {
      // TODO: Calling RegistrationService service directly is not good. Refactor this.
      final challengeId = store.state.authState.pendingChallengeId;
      if (challengeId == null) {
        action.completer.completeError('No active challenge.');
        return;
      }

      final user = await RegistrationService().submitEmailCodeForToken(
          challengeId: challengeId,
          code: action.code,
          displayName: store.state.authState.pendingDisplayName);
      if (user != null) {
        store.dispatch(OnAuthenticatedAction(user: user));

        final completer = Completer();
        completer.future.then((val) {
          store.dispatch(
              NavigateToNewRouteAction(route: AppNavigation.selectTeamPath));
        }).catchError((error) {
          // TODO: Handle error better here..
          debugPrint(error);
        });
        store.dispatch(ListMyTeamsRequestAction(
            accessToken: user.accessToken, completer: completer));
        action.completer.complete(user);
      } else {
        action.completer.completeError('Login failed.');
      }
    } on PlatformException catch (e) {
      action.completer.completeError(e);
    }
  };
}

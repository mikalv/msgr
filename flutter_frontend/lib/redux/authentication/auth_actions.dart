// Authentication
import 'dart:async';

import 'package:libmsgr/libmsgr.dart';
import 'package:meta/meta.dart';

class AuthActions {}

class VerifyAuthStateAction extends AuthActions {
  @override
  String toString() {
    return 'VerifyAuthStateAction{}';
  }
}

class OpenWebsocketIfNotAlready extends AuthActions {
  @override
  String toString() {
    return 'OpenWebsocketIfNotAlready{}';
  }
}

class OnWebSocketConnectedAction extends AuthActions {
  @override
  String toString() {
    return 'OnWebSocketConnectedAction{}';
  }
}

class OnWebsocketConnectionFailedAction extends AuthActions {
  final dynamic error;

  OnWebsocketConnectionFailedAction(this.error);

  @override
  String toString() {
    return 'OnWebsocketConnectionFailedAction{error: $error}';
  }
}

class ListMyTeamsRequestAction extends AuthActions {
  final String accessToken;
  final Completer completer;

  ListMyTeamsRequestAction(
      {required this.accessToken, required this.completer});

  @override
  String toString() {
    return 'ListMyTeamsRequestAction{accessToken: $accessToken}';
  }
}

class CreateTeamRequestAction extends AuthActions {
  final String teamName;
  final String teamDesc;

  CreateTeamRequestAction({required this.teamName, required this.teamDesc});

  @override
  String toString() {
    return 'CreateTeamRequestAction{teamName: $teamName, teamDesc: "${teamDesc.replaceAll("\n", "\\n")}"}';
  }
}

class OnCreateTeamSuccessAction extends AuthActions {
  final String teamName;
  final String teamID;
  final Team team;

  OnCreateTeamSuccessAction(
      {required this.teamName, required this.teamID, required this.team});

  @override
  String toString() {
    return 'OnCreateTeamSuccessAction{teamName: $teamName, teamId: $teamID}"}';
  }
}

class OnCreateTeamFailureAction extends AuthActions {
  final String teamName;
  final String error;

  OnCreateTeamFailureAction({required this.teamName, required this.error});

  @override
  String toString() {
    return 'CreateTeamResponseFailureAction{teamName: $teamName, error: $error}"}';
  }
}

class OnListMyTeamsResponseAction extends AuthActions {
  final List<Team> teams;

  OnListMyTeamsResponseAction({required this.teams});
  @override
  String toString() {
    return 'OnListMyTeamsResponseAction{teams: ${teams.toString()}}';
  }
}

class ServerRequestCodeFromUserAction extends AuthActions {
  final String channel;
  final AuthChallenge challenge;

  ServerRequestCodeFromUserAction({required this.channel, required this.challenge});

  @override
  String toString() {
    return 'ServerRequestCodeFromUserAction{channel: $channel, challenge: ${challenge.id}}';
  }
}

class RequestCodeMsisdnAction extends AuthActions {
  final String msisdn;
  final String? displayName;
  final Completer completer;

  RequestCodeMsisdnAction({required this.msisdn, this.displayName, required Completer completer})
      : completer = completer ?? Completer();

  @override
  String toString() {
    return 'RequestCodeMsisdnAction{msisdn: $msisdn, displayName: $displayName}';
  }
}

class RequestCodeEmailAction extends AuthActions {
  final String email;
  final String? displayName;
  final Completer completer;

  RequestCodeEmailAction({required this.email, this.displayName, required Completer completer})
      : completer = completer ?? Completer();

  @override
  String toString() {
    return 'RequestCodeEmailAction{email: $email, displayName: $displayName}';
  }
}

class LogInEmailAction extends AuthActions {
  final String email;
  final String code;
  final Completer completer;

  LogInEmailAction(
      {required this.email, required this.code, required Completer completer})
      : completer = completer ?? Completer();

  @override
  String toString() {
    return 'LogInEmailAction{email: $email, code: $code}';
  }
}

class LogInMsisdnAction extends AuthActions {
  final String msisdn;
  final String code;
  final Completer completer;

  LogInMsisdnAction(
      {required this.msisdn, required this.code, required Completer completer})
      : completer = completer ?? Completer();

  @override
  String toString() {
    return 'LogInMsisdnAction{msisdn: $msisdn, code: $code}';
  }
}

@immutable
class OnAuthFailureAction extends AuthActions {
  final String error;
  final String details;

  OnAuthFailureAction({required this.error, required this.details});

  @override
  String toString() {
    return 'OnAuthFailure{error: $error, details: $details}';
  }
}

class SelectAndAuthWithTeamAction extends AuthActions {
  final String teamName;

  SelectAndAuthWithTeamAction({required this.teamName});

  @override
  String toString() {
    return 'SelectAndAuthWithTeamAction{teamName: $teamName}';
  }
}

class OnAuthenticatedWithTeamAction extends AuthActions {
  final String teamAccessToken;
  final String teamName;
  final Profile? profile;
  final String nextAction;

  OnAuthenticatedWithTeamAction(
      {required this.teamAccessToken,
      required this.teamName,
      this.profile,
      required this.nextAction});

  @override
  String toString() {
    String pro;
    if (profile == null) {
      pro = 'none_yet';
    } else {
      pro = profile.toString();
    }
    return 'OnAuthenticatedWithTeamAction{teamName: $teamName, teamAccessToken: $teamAccessToken, profile: $pro}';
  }
}

@immutable
class OnAuthenticatedAction extends AuthActions {
  final User user;

  OnAuthenticatedAction({required this.user});

  @override
  String toString() {
    return 'OnAuthenticated{user: ${user.toString()}}';
  }
}

class LogOutAction extends AuthActions {}

class OnLogoutSuccessAction extends AuthActions {
  OnLogoutSuccessAction();

  @override
  String toString() {
    return 'LogOut{user: null}';
  }
}

class OnLogoutFailAction extends AuthActions {
  final dynamic error;

  OnLogoutFailAction(this.error);

  @override
  String toString() {
    return 'OnLogoutFail{There was an error logging in: $error}';
  }
}

class OnConnectedToServerAction extends AuthActions {
  @override
  String toString() {
    return 'OnConnectedToServerAction{}';
  }
}

class OnDisconnectedFromServerAction extends AuthActions {
  @override
  String toString() {
    return 'OnDisconnectedFromServerAction{}';
  }
}

// ignore_for_file: must_be_immutable

import 'dart:ui';

import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/redux/authentication/auth_state.dart';
import 'package:messngr/redux/team_state.dart';
import 'package:messngr/redux/ui/ui_state.dart';
import 'package:meta/meta.dart';

@immutable

/// Represents the state of the application.
///
/// This class holds the entire state tree of the application, which can be
/// used to manage and access various pieces of state throughout the app.
///
/// The state is typically immutable and can only be modified by dispatching
/// actions that are handled by reducers.
class AppState {
  AuthState authState;
  TeamState? teamState;
  Profile? currentProfile;
  UiState uiState;

  String currentRoute;

  Exception? error;

  AppState(
      {required this.authState,
      required this.teamState,
      required this.currentRoute,
      required this.uiState,
      this.currentProfile,
      this.error});

  factory AppState.initial() => AppState(
      teamState: null,
      uiState: UiState(
          windowPosition: const Offset(0, 0), windowSize: const Size(800, 600)),
      authState: AuthState(
        kIsLoggedIn: false,
        currentUser: null,
        currentProfile: null,
        teams: [],
        isLoading: true,
      ),
      currentRoute: AppNavigation.welcomePath);

  AppState copyWith({
    required Exception? error,
    required Profile? currentProfile,
    required AuthState authState,
    required UiState uiState,
    required TeamState teamState,
    required String currentRoute,
  }) {
    return AppState(
        authState: authState,
        teamState: teamState,
        currentProfile: currentProfile,
        uiState: uiState,
        currentRoute: currentRoute,
        error: error);
  }

  @override
  bool operator ==(other) =>
      identical(this, other) ||
      other is AppState &&
          authState == other.authState &&
          currentProfile == other.currentProfile &&
          currentRoute == other.currentRoute &&
          teamState == other.teamState &&
          uiState == other.uiState;

  @override
  int get hashCode =>
      super.hashCode ^
      authState.hashCode ^
      currentProfile.hashCode ^
      currentRoute.hashCode ^
      teamState.hashCode ^
      uiState.hashCode;

  @override
  String toString() {
    return 'AppState{authState: ${authState.toString()} '
        'teamState: ${teamState.toString()} '
        'uiState: ${uiState.toString()} '
        'currentProfile: ${currentProfile.toString()}'
        ' currentRoute: $currentRoute}';
  }

  factory AppState.fromJson(dynamic json) {
    if (json == null) {
      return AppState(
          teamState: null,
          uiState: UiState(
              isLoading: false,
              hasFocus: true,
              windowSize: const Size(0, 0),
              windowPosition: const Offset(0, 0)),
          authState: AuthState.fromJson(null),
          currentRoute: '/welcome');
    }
    Profile? profile;
    if (json['currentProfile'] != null) {
      profile = Profile.fromJson(json['currentProfile']);
    } else {
      profile = null;
    }
    return AppState(
        uiState: UiState(
            isLoading: false,
            hasFocus: true,
            windowSize: const Size(0, 0),
            windowPosition: const Offset(0, 0)),
        authState: AuthState.fromJson(json['authState']),
        teamState: TeamState.fromJson(json['teamState']),
        currentRoute: json['currentRoute'],
        currentProfile: profile);
  }

  Map<String, dynamic> toJson() => {
        'authState': authState.toJson(),
        'teamState': teamState?.toJson(),
        'currentProfile': currentProfile?.toJson(),
        'currentRoute': currentRoute
      };
}

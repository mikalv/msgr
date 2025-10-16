// ignore_for_file: implicit_call_tearoffs

import 'package:libmsgr/libmsgr.dart';
import 'package:logging/logging.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/features/auth/auth_identity_store.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/authentication/auth_actions.dart';
import 'package:messngr/redux/navigation/navigation_actions.dart';
import 'package:messngr/redux/profile/profile_actions.dart';
import 'package:messngr/services/api/profile_api.dart';
import 'package:redux/redux.dart';
import 'package:libmsgr/src/registration_service.dart';

final Logger _log = Logger('ProfileMiddleware');

List<Middleware<AppState>> createProfileMiddleware() {
  final api = ProfileApi();
  final identityStore = AuthIdentityStore.instance;

  return [
    TypedMiddleware<AppState, CreateProfileAction>(_createProfile()),
    TypedMiddleware<AppState, RefreshProfilesAction>(_refreshProfiles(api)),
    TypedMiddleware<AppState, SwitchProfileAction>(
        _switchProfile(api, identityStore)),
  ];
}

void Function(
  Store<AppState> store,
  CreateProfileAction action,
  NextDispatcher next,
) _createProfile() {
  return (store, action, next) async {
    next(action);
    final result = await RegistrationService().createProfileForTeam(
      teamName: store.state.authState.currentTeamName!,
      token: store.state.authState.teamAccessToken!,
      username: action.username,
      firstName: action.firstName,
      lastName: action.lastName,
    );
    if (result != null) {
      store.dispatch(OnCreateProfileSuccessAction(profile: result));
      store.dispatch(SelectAndAuthWithTeamAction(
          teamName: store.state.authState.currentTeamName!));
    } else {
      store.dispatch(
          OnCreateProfileFailureAction(msg: 'Error creating profile!'));
    }
  };
}

void Function(
  Store<AppState> store,
  RefreshProfilesAction action,
  NextDispatcher next,
) _refreshProfiles(ProfileApi api) {
  return (store, action, next) async {
    next(action);
    try {
      final profiles =
          await api.listProfiles(identity: action.identity);
      store.dispatch(RefreshProfilesSuccessAction(profiles: profiles));
    } catch (error, stackTrace) {
      _log.warning('Failed to refresh profiles', error, stackTrace);
      store.dispatch(
        RefreshProfilesFailureAction(error: error.toString()),
      );
    }
  };
}

void Function(
  Store<AppState> store,
  SwitchProfileAction action,
  NextDispatcher next,
) _switchProfile(ProfileApi api, AuthIdentityStore identityStore) {
  return (store, action, next) async {
    next(action);
    try {
      final result = await api.switchProfile(
        identity: action.identity,
        profileId: action.profileId,
      );
      await identityStore.save(
        result.identity,
        displayName: result.profile.displayName,
      );
      store.dispatch(SwitchProfileSuccessAction(
        profile: result.profile,
        identity: result.identity,
        device: result.device,
      ));
      action.completer.complete(result);
    } catch (error, stackTrace) {
      _log.severe('Failed to switch profile', error, stackTrace);
      store.dispatch(
        SwitchProfileFailureAction(error: error.toString()),
      );
      action.completer.completeError(error, stackTrace);
    }
  };
}

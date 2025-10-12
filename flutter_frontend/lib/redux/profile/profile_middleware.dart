// ignore_for_file: implicit_call_tearoffs

import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/authentication/auth_actions.dart';
import 'package:messngr/redux/navigation/navigation_actions.dart';
import 'package:messngr/redux/profile/profile_actions.dart';
import 'package:redux/redux.dart';
import 'package:libmsgr/src/registration_service.dart';

List<Middleware<AppState>> createProfileMiddleware() {
  return [TypedMiddleware<AppState, CreateProfileAction>(_createProfile())];
}

void Function(
  Store<AppState> store,
  CreateProfileAction action,
  NextDispatcher next,
) _createProfile() {
  return (store, action, next) async {
    next(action);
    // TODO: Calling RegistrationService service directly is not good. Refactor this.
    final result = await RegistrationService().createProfile(
        store.state.authState.currentTeamName!,
        store.state.authState.teamAccessToken!,
        action.username,
        action.firstName,
        action.lastName);
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

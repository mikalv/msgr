// ignore_for_file: implicit_call_tearoffs

import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/invitation/invitation_actions.dart';
import 'package:redux/redux.dart';

List<Middleware<AppState>> createInvitationMiddlewares() {
  return [
    TypedMiddleware<AppState, InviteUserToTeamAction>(_inviteUserToTeam),
    TypedMiddleware<AppState, InviteProfileToRoomAction>(_inviteProfileToRoom),
    TypedMiddleware<AppState, InviteProfileToConversationAction>(
        _inviteProfileToConversation),
  ];
}

void _inviteUserToTeam(Store<AppState> store, InviteUserToTeamAction action,
    NextDispatcher next) async {
  next(action);
  try {
    final wsConn = LibMsgr().getWebsocketConnection();
    final push = wsConn?.sendInvitation(action.teamName,
        store.state.authState.currentProfile!.id, action.identifier);
    push?.future
        .then((_) =>
            store.dispatch(OnInviteUserToTeamSuccessAction('Invitation sent')))
        .onError((e, st) =>
            store.dispatch(OnInviteUserToTeamFailureAction(e.toString(), st)));
  } catch (e, stackTrace) {
    store.dispatch(OnInviteUserToTeamFailureAction(e.toString(), stackTrace));
  }
}

void _inviteProfileToRoom(Store<AppState> store,
    InviteProfileToRoomAction action, NextDispatcher next) async {
  next(action);
  try {
    const msg = '';
    store.dispatch(OnInviteProfileToRoomSuccessAction(msg));
  } catch (e) {
    store.dispatch(OnInviteProfileToRoomFailureAction(e.toString()));
  }
}

void _inviteProfileToConversation(Store<AppState> store,
    InviteProfileToConversationAction action, NextDispatcher next) async {
  next(action);
  try {
    const msg = '';
    store.dispatch(OnInviteProfileToConversationSuccessAction(msg));
  } catch (e) {
    store.dispatch(OnInviteProfileToConversationFailureAction(e.toString()));
  }
}

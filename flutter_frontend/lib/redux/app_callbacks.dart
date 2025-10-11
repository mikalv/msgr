// The purpose of this file is to provide callbacks to be used in LibMsgr without
// having to import the entire application state. This is useful for when you need
// to access the application state in a file that is not part of the Redux store.

import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/conversation_room/conversation_room_actions.dart';
import 'package:redux/redux.dart';

void handleInitialCRServerData(
    Store<AppState> store, List<Room> rooms, List<Conversation> conversations) {
  store.dispatch(UpdateRoomsAction(rooms));
  store.dispatch(UpdateConversationsAction(conversations));
}

void Function(MMessage) getNewMessageHandler(Store<AppState> store) {
  return (MMessage message) {
    store.dispatch(OnReceiveMessageAction(msg: message));
  };
}

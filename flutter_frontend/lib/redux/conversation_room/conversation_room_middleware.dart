// ignore_for_file: implicit_call_tearoffs

import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/conversation_room/conversation_room_actions.dart';
import 'package:redux/redux.dart';

List<Middleware<AppState>> createConversationsMiddlewares() {
  return [
    TypedMiddleware<AppState, OnListConversationsResponseAction>(
        _onListConversations()),
    TypedMiddleware<AppState, OnServerRefreshConversationsAction>(
        _onServerRefreshConversations()),
  ];
}

List<Middleware<AppState>> createRoomsMiddlewares() {
  return [
    TypedMiddleware<AppState, CreateRoomAction>(_onCreateRoom()),
    TypedMiddleware<AppState, OnListRoomsResponseAction>(
        _onListRooms()),
    TypedMiddleware<AppState, OnServerRefreshRoomsAction>(
        _onServerRefreshRooms()),
  ];
}

void Function(
        Store<AppState> store, CreateRoomAction action, NextDispatcher next)
    _onCreateRoom() {
  return (store, action, next) {
    next(action);
  };
}

void Function(
  Store<AppState> store,
  OnServerRefreshConversationsAction action,
  NextDispatcher next,
) _onServerRefreshConversations() {
  return (store, action, next) {
    next(action);
    if (action.conversations.isNotEmpty) {
      for (var conversation in action.conversations) {
        print('Found conversation: $conversation');
      }
    }
  };
}

void Function(
  Store<AppState> store,
  OnServerRefreshRoomsAction action,
  NextDispatcher next,
) _onServerRefreshRooms() {
  return (store, action, next) {
    next(action);
    if (action.rooms.isNotEmpty) {
      for (var room in action.rooms) {
        print('Found room: $room');
      }
    }
  };
}

void Function(
  Store<AppState> store,
  OnListConversationsResponseAction action,
  NextDispatcher next,
) _onListConversations() {
  return (store, action, next) {
    next(action);
    if (action.conversations.isNotEmpty) {}
  };
}

void Function(
  Store<AppState> store,
  OnListRoomsResponseAction action,
  NextDispatcher next,
) _onListRooms() {
  return (store, action, next) {
    next(action);
  };
}

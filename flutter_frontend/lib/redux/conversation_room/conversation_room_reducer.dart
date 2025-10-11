// ignore_for_file: implicit_call_tearoffs

import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/redux/conversation_room/conversation_room_actions.dart';
import 'package:messngr/redux/team_state.dart';
import 'package:redux/redux.dart';

final conversationAndRoomsReducers = combineReducers([
  TypedReducer<TeamState, OnServerRefreshRoomsAction>(
      _onServerRefreshRoomsResponse),
  TypedReducer<TeamState, OnServerRefreshConversationsAction>(
      _onServerRefreshConversationsResponse),
  TypedReducer<TeamState, OnReceiveNewRoomAction>(_onReceiveNewRoom),
  TypedReducer<TeamState, OnReceiveNewConversationAction>(
      _onReceiveNewConversation),
]);

final roomsReducer = combineReducers<List<Room>>([
  TypedReducer<List<Room>, UpdateRoomsAction>(_updateRooms),
]);

final conversationsReducer = combineReducers<List<Conversation>>([
  TypedReducer<List<Conversation>, UpdateConversationsAction>(
      _updateConversations),
]);

List<Room> _updateRooms(List<Room> state, UpdateRoomsAction action) {
  return action.rooms;
}

List<Conversation> _updateConversations(
    List<Conversation> state, UpdateConversationsAction action) {
  return action.conversations;
}

TeamState _onReceiveNewRoom(TeamState state, OnReceiveNewRoomAction action) {
  return TeamState(
    conversations: state.conversations,
    rooms: state.rooms..add(action.room),
    currentRoom: state.currentRoom,
    currentConversation: state.currentConversation,
    selectedTeam: state.selectedTeam,
    profiles: state.profiles,
  );
}

TeamState _onReceiveNewConversation(
    TeamState state, OnReceiveNewConversationAction action) {
  return TeamState(
    conversations: state.conversations..add(action.conversation),
    rooms: state.rooms,
    currentRoom: state.currentRoom,
    currentConversation: state.currentConversation,
    selectedTeam: state.selectedTeam,
    profiles: state.profiles,
  );
}

TeamState _onServerRefreshRoomsResponse(
    TeamState state, OnServerRefreshRoomsAction action) {
  return TeamState(
    conversations: state.conversations,
    rooms: action.rooms,
    currentRoom: state.currentRoom,
    currentConversation: state.currentConversation,
    selectedTeam: state.selectedTeam,
    profiles: state.profiles,
  );
}

TeamState _onServerRefreshConversationsResponse(
    TeamState state, OnServerRefreshConversationsAction action) {
  return TeamState(
    conversations: action.conversations,
    rooms: state.rooms,
    currentRoom: state.currentRoom,
    currentConversation: state.currentConversation,
    selectedTeam: state.selectedTeam,
    profiles: state.profiles,
  );
}

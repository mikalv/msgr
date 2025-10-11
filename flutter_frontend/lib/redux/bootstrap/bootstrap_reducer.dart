// ignore_for_file: implicit_call_tearoffs

import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/redux/team_state.dart';
import 'package:redux/redux.dart';

Reducer<TeamState> bootstrapReducersCombined = combineReducers([
  TypedReducer<TeamState, OnBootstrapAction>(_onBootstrapTeam),
]);

TeamState _onBootstrapTeam(TeamState state, OnBootstrapAction action) {
  return state.copyWith(
      conversations: action.conversations,
      rooms: action.rooms,
      profiles: action.profiles);
}

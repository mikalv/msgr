import 'package:logging/logging.dart';
import 'package:messngr/redux/app/app_reducer.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/authentication/auth_reducer.dart';
import 'package:messngr/redux/authentication/auth_state.dart';
import 'package:messngr/redux/bootstrap/bootstrap_reducer.dart';
import 'package:messngr/redux/conversation_room/conversation_room_reducer.dart';
import 'package:messngr/redux/navigation/navigation_reducer.dart';
import 'package:messngr/redux/profile/profile_reducer.dart';
import 'package:messngr/redux/team_state.dart';
import 'package:messngr/redux/ui/ui_reducer.dart';
import 'package:redux/redux.dart';

//final appReducer = combineReducers<AppState>([]);
final Logger _log = Logger('appReducer');

AppState mainReducer(AppState state, action) {
  //_log.info('Redux: ${action.toString()}');
  final authReducersCombined = combineReducers<AuthState>(authReducers);
  //state = appReducersCombined(state, action);
  state = profileReducersCombined(state, action);
  state = appReducersCombined(state, action);
  final teamState = bootstrapReducersCombined(conversationAndRoomsReducers(
          state.teamState ??
              TeamState(
                  conversations: [],
                  rooms: [],
                  currentRoom: null,
                  currentConversation: null,
                  selectedTeam: state.authState.currentTeam),
          action), action);
  return AppState(
      teamState: teamState,
      uiState: uiReducersCombined(state.uiState, action),
      authState: authReducersCombined(state.authState, action),
      currentRoute: currentRouteReducer(state.currentRoute, action),
      currentProfile: state.currentProfile,
      error: state.error);
}

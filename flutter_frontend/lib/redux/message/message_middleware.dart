// ignore_for_file: implicit_call_tearoffs

import 'package:libmsgr/libmsgr.dart';
import 'package:logging/logging.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/message/message_actions.dart';
import 'package:redux/redux.dart';

final Logger _log = Logger('MessageMiddlewares');

List<Middleware<AppState>> createMessageMiddlewares() {
  return [TypedMiddleware<AppState, SendMessageAction>(_onSendMessage())];
}

void Function(
  Store<AppState> store,
  SendMessageAction action,
  NextDispatcher next,
) _onSendMessage() {
  return (store, action, next) async {
    next(action);
    try {
      final repos = LibMsgr()
          .repositoryFactory
          .getRepositories(store.state.authState.currentTeamName!);
      final push = repos.messageRepository.sendMessageToRoom(action.msg);
      if (push == null) {
        const error = 'Failed to enqueue message.';
        action.completer.completeError(error);
        store.dispatch(
          OnSendMessageFailureAction(msg: action.msg, serverResponse: error),
        );
        return;
      }

      push.future.then((value) {
        action.completer.complete();
        store.dispatch(
          OnSendMessageSuccessAction(
            msg: action.msg,
            serverResponse: value,
          ),
        );
      }).catchError((e) {
        action.completer.completeError(e);
        store.dispatch(
          OnSendMessageFailureAction(
            msg: action.msg,
            serverResponse: e.toString(),
          ),
        );
      });
    } catch (e) {
      _log.severe('Error sending message: ${e.toString()}');
      store.dispatch(OnSendMessageFailureAction(
          msg: action.msg, serverResponse: e.toString()));
    }
  };
}

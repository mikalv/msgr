import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/repositories/base.dart';
import 'package:phoenix_socket/phoenix_socket.dart';

class ConversationRepository extends BaseRepository<Conversation> {
  ConversationRepository({required super.teamName}) {
    log.info('ConversationRepository is starting up');
  }

  Push? createConversation(
      {profileID, topic, isSecret = false, List<String>? members}) {
    members ??= <String>[];
    final wsConn = LibMsgr().getWebsocketConnection();
    final push =
        wsConn?.createConversation(profileID, topic, isSecret, members);
    return push;
  }

  List<Conversation> get conversations => items.toList();
}

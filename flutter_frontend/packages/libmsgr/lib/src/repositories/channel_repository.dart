import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/repositories/base.dart';
import 'package:phoenix_socket/phoenix_socket.dart';

class ChannelRepository extends BaseRepository<Channel> {
  ChannelRepository({required super.teamName}) {
    log.info('ChannelRepository is starting up');
  }

  Push? createChannel(
      {profileID,
      channelName,
      channelDescription,
      isSecret = false,
      List<String>? members}) {
    members ??= <String>[];
    final wsConn = LibMsgr().getWebsocketConnection();
    final push = wsConn?.createChannel(
        profileID, channelName, channelDescription, isSecret, members);
    return push;
  }

  Channel fetchByName(String name) {
    return items.firstWhere((channel) => channel.name == name);
  }
}

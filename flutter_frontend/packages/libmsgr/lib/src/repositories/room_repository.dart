import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/repositories/base.dart';
import 'package:phoenix_socket/phoenix_socket.dart';

class RoomRepository extends BaseRepository<Room> {
  RoomRepository({required super.teamName}) {
    log.info('RoomRepository is starting up');
  }

  Push? createRoom(
      {profileID,
      roomName,
      roomDescription,
      isSecret = false,
      List<String>? members}) {
    members ??= <String>[];
    final wsConn = LibMsgr().getWebsocketConnection();
    final push = wsConn?.createRoom(
        profileID, roomName, roomDescription, isSecret, members);
    return push;
  }

  Room fetchByName(String name) {
    return items.firstWhere((room) => room.name == name);
  }
}

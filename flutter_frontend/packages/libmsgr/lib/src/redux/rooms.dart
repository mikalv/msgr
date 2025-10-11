import 'package:libmsgr/libmsgr.dart';

/// This is used when we get a (one) new room from the server.
class OnReceiveNewRoomAction {
  final Room room;

  OnReceiveNewRoomAction(this.room);

  @override
  String toString() {
    return 'OnReceiveNewRoomAction{room: $room}';
  }
}

/// This is used when we get the whole list of rooms from the server.
class OnReceiveRoomsAction {
  final List<Room> rooms;

  OnReceiveRoomsAction({required this.rooms});

  @override
  String toString() {
    return 'OnReceiveRoomsAction{rooms: $rooms}';
  }
}

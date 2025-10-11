import 'package:libmsgr/libmsgr.dart';

class CreateRoomAction {
  final String name;
  final String description;
  final String topic;
  final List<String> members;
  final bool isSecret;

  CreateRoomAction({
    required this.name,
    required this.description,
    required this.topic,
    this.members = const [],
    this.isSecret = false,
  });

  @override
  String toString() {
    return 'CreateRoomAction{name: $name, '
        'description: $description, topic: $topic,'
        ' members: $members, isSecret: $isSecret}';
  }
}

class UpdateRoomsAction {
  final List<Room> rooms;
  UpdateRoomsAction(this.rooms);

  @override
  String toString() {
    return 'UpdateRoomsAction{rooms: $rooms}';
  }
}

class UpdateConversationsAction {
  final List<Conversation> conversations;
  UpdateConversationsAction(this.conversations);

  @override
  String toString() {
    return 'UpdateConversationsAction{conversations: $conversations}';
  }
}

class LoadConversations {
  final String teamID;

  LoadConversations({required this.teamID});

  @override
  String toString() {
    return 'LoadConversations{teamID: $teamID}';
  }
}

class LoadRooms {
  final String teamID;

  LoadRooms({required this.teamID});

  @override
  String toString() {
    return 'LoadRooms{teamID: $teamID}';
  }
}

class OnServerRefreshRoomsAction {
  final List<Room> rooms;

  OnServerRefreshRoomsAction({required this.rooms});

  @override
  String toString() {
    return 'OnServerRefreshRoomsAction{rooms: $rooms}';
  }
}

class OnServerRefreshConversationsAction {
  final List<Conversation> conversations;

  OnServerRefreshConversationsAction({required this.conversations});

  @override
  String toString() {
    return 'OnServerRefreshConversationsAction{conversations: $conversations}';
  }
}

class OnListRoomsResponseAction {
  final List<Room> rooms;

  OnListRoomsResponseAction({required this.rooms});

  @override
  String toString() {
    return 'OnListRoomsResponseAction{rooms: $rooms}';
  }
}

class OnListConversationsResponseAction {
  final List<Conversation> conversations;

  OnListConversationsResponseAction({required this.conversations});

  @override
  String toString() {
    return 'OnListConversationsResponseAction{conversations: $conversations}';
  }
}

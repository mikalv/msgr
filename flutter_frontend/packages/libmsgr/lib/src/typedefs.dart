import 'package:libmsgr/libmsgr.dart';

typedef TeamNameType = String;

typedef ConversationCacheType = Map<String, Conversation>;
typedef ConversationList = List<Conversation>;

typedef MessageCacheType = Map<String, List<MMessage>>;
typedef MessagesInTransit = List<MMessage>;
typedef MessageList = List<MMessage>;

typedef ProfileCacheType = Map<String, Profile>;
typedef ProfileList = List<Profile>;

typedef RoomCacheType = Map<String, Room>;

typedef RoomList = List<Room>;
typedef RoomEventCallback = void Function(List<Room>);
typedef Rooms = Map<String, Room>;

typedef MessageHandler = void Function(MMessage event);

typedef ReduxDispatchCallback = void Function(dynamic event);

typedef VoidCallback = void Function();

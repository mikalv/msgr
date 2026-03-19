import 'package:libmsgr/libmsgr.dart';

typedef TeamNameType = String;

typedef ConversationCacheType = Map<String, Conversation>;
typedef ConversationList = List<Conversation>;

typedef MessageCacheType = Map<String, List<MMessage>>;
typedef MessageList = List<MMessage>;

typedef ProfileCacheType = Map<String, Profile>;
typedef ProfileList = List<Profile>;

typedef ChannelCacheType = Map<String, Channel>;

typedef ChannelList = List<Channel>;
typedef ChannelEventCallback = void Function(List<Channel>);
typedef Channels = Map<String, Channel>;

typedef MessageHandler = void Function(MMessage event);

typedef ReduxDispatchCallback = void Function(dynamic event);

typedef VoidCallback = void Function();

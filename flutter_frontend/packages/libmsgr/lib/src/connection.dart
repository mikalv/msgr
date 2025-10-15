import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/telemetry/socket_telemetry.dart';
import 'package:libmsgr/src/typedefs.dart';
import 'package:libmsgr/src/utils/events.dart';
import 'package:logging/logging.dart';
import 'package:phoenix_socket/phoenix_socket.dart';

class MsgrConnection {
  late PhoenixSocket _socket;
  late PhoenixPresence _presence;
  late PhoenixChannel userChannel;
  final ReduxDispatchCallback dispatchFn;
  final String tenant;
  final String userID;
  bool _connected = false;

  final Logger _log = Logger('MsgrConnection');
  final IDelegate<String> connectDelegate = Delegate();
  final List<PhoenixChannel> _connectedChannels = [];

  MsgrConnection(String serverUrl, Map<String, String> params, this.tenant,
      this.userID, this.dispatchFn) {
    _socket = PhoenixSocket(serverUrl,
        socketOptions: PhoenixSocketOptions(params: params));
  }

  List<PhoenixChannel> get connectedChannels => _connectedChannels;

  connect() async {
    await _socket.connect();
    _socket.errorStream.listen(_handleError);
    _socket.closeStream.listen(_handleDisconnect);
    _socket.openStream.listen(_handleConnect);
    /*_socket.streamForTopic('room:lobby').listen((onData) {
      _log.info('ondata: $onData');
    });*/
  }

  PhoenixChannel joinChannel(topic) {
    if (_socket.channels.keys.toList().contains(topic)) {
      return _socket.channels[topic]!;
    }
    final chl = _socket.addChannel(topic: topic);
    _connectedChannels.add(chl);
    chl.join();
    chl.messages.listen(_everyChannelSink);
    return chl;
  }

  void leaveChannel(PhoenixChannel chl) {
    chl.leave();
    _connectedChannels.remove(chl);
  }

  void presenceOnSync() {
    _log.info('presence sync');
  }

  void _handleError(event) {
    _log.severe('Websocket error: ${event.toString()}');
  }

  void _handleConnect(event) async {
    _connected = true;
    _log.info('[+] Socket connected: ${event.toString()}');
    // TODO: This probably needs to be namespaced by team
    joinChannel('room:lobby');
    userChannel = joinChannel('user:$userID');
    _presence = PhoenixPresence(channel: userChannel);
    _presence.onSync = presenceOnSync;
  }

  void _handleDisconnect(event) {
    _log.info('[-] Socket disconnected! event: ${event.toString()}');
    _connected = false;
  }

  List<Room> _handleRoomsPacket(
      TeamRepositories repos, String team, dynamic rooms) {
    final roomObjs = rooms.map<Room>((e) => Room.fromJson(e)).toList();
    for (var room in roomObjs) {
      dispatchFn(OnReceiveNewRoomAction(room));
      joinChannel('room:$team.${room.id}');
    }
    repos.roomRepository.fillLocalCache(roomObjs);
    return roomObjs;
  }

  List<Conversation> _handleConversationsPacket(
      TeamRepositories repos, String team, dynamic conversations) {
    final conversationObjs = conversations
        .map<Conversation>((e) => Conversation.fromJson(e))
        .toList();
    for (var conversation in conversationObjs) {
      dispatchFn(OnReceiveNewConversationAction(conversation));
      joinChannel('conversation:$team.${conversation.id}');
    }
    repos.conversationRepository.fillLocalCache(conversationObjs);
    return conversationObjs;
  }

  List<Profile> _handleProfilesPacket(
      TeamRepositories repos, String team, dynamic profiles) {
    final profileObjs =
        profiles.map<Profile>((e) => Profile.fromJson(e)).toList();
    repos.profileRepository.fillLocalCache(profileObjs);
    dispatchFn(OnReceiveProfilesAction(profiles: profileObjs));
    return profileObjs;
  }

  List<MMessage> _handleMessagesPacket(
      TeamRepositories repos, String team, dynamic messages) {
    final messageObjs =
        messages.map<MMessage>((e) => MMessage.fromJson(e)).toList();
    repos.messageRepository.fillLocalCache(messageObjs);
    for (var message in messageObjs) {
      dispatchFn(OnReceiveMessageAction(msg: message));
    }
    return messageObjs;
  }

  void _handleNewMessagePacket(event) {
    _log.finest('Debug: ${event.payload}');
    final msg = MMessage.fromJson(event.payload);
    final (team, channel) = getTeamAndChannelFromTopic(event.topic);
    final repos = LibMsgr().repositoryFactory.getRepositories(team);
    repos.messageRepository.fillLocalCache([msg]);
    dispatchFn(OnReceiveMessageAction(msg: msg));
  }

  void _handleBootstrapPacket(event) {
    final roomAndConvMap = event.payload['data'];
    final String team = roomAndConvMap['team'];
    TeamRepositories repos = LibMsgr().repositoryFactory.getRepositories(team);
    final List<dynamic> rooms = roomAndConvMap['rooms'];
    final roomObjs = _handleRoomsPacket(repos, team, rooms);
    final List<dynamic> conversations = roomAndConvMap['conversations'];
    final conversationObjs =
        _handleConversationsPacket(repos, team, conversations);
    final List<dynamic> profiles = roomAndConvMap['profiles'];
    final profileObjs = _handleProfilesPacket(repos, team, profiles);
    final List<dynamic> messages = roomAndConvMap['messages'];
    final messageObjs = _handleMessagesPacket(repos, team, messages);
    dispatchFn(OnBootstrapAction(
        profiles: profileObjs,
        conversations: conversationObjs,
        rooms: roomObjs,
        messages: messageObjs,
        teamName: team));
  }

  void _everyChannelSink(event) {
    final String team = event.payload['team'] ?? 'unknown';
    final TeamRepositories repos =
        LibMsgr().repositoryFactory.getRepositories(team);
    if (event.event == PhoenixChannelEvent.custom('bootstrap:packet')) {
      _handleBootstrapPacket(event);
    } else if (event.event == PhoenixChannelEvent.custom('new:msg')) {
      _handleNewMessagePacket(event);
    } else if (event.event == PhoenixChannelEvent.custom("new:room")) {
      _handleRoomsPacket(repos, team, event.payload['rooms']);
    } else if (event.event == PhoenixChannelEvent.custom("new:conversation")) {
      _handleConversationsPacket(repos, team, event.payload['conversations']);
    } else {
      _log.info('GOT Unhandled event: ${event.toString()}');
    }
  }

  (String, String) getTeamAndChannelFromTopic(String topic) {
    final parts1 = topic.split(':');
    final parts = parts1[1].split('.');
    return (parts[0], parts[1]);
  }

  Push? sendMessage(String destID, MMessage msg) {
    final key = (msg.roomID != null) ? 'room:$destID' : 'conversation:$destID';
    if (_socket.channels.containsKey(key)) {
      final chl = _socket.channels[key]!;
      SocketTelemetry.instance.messageSent(
        conversationId: msg.conversationID ?? msg.roomID ?? destID,
        messageId: msg.id,
        metadata: {'topic': key},
      );

      final push = chl.push('create:msg', msg.toMap());
      push?.future.then((response) {
        SocketTelemetry.instance.messageAcknowledged(
          conversationId: msg.conversationID ?? msg.roomID ?? destID,
          messageId: msg.id,
          metadata: {
            'topic': key,
            'status': response?.status ?? 'ok',
          },
        );
      }).catchError((error) {
        SocketTelemetry.instance.messageAcknowledged(
          conversationId: msg.conversationID ?? msg.roomID ?? destID,
          messageId: msg.id,
          metadata: {
            'topic': key,
            'status': 'error',
            'error': error.toString(),
          },
        );
      });

      return push;
    } else {
      _log.severe('Channel $destID not found!');
      throw Exception('Channel $destID not found!');
    }
  }

  Push? createRoom(String profileID, String roomName, String roomDescription,
      bool isSecret, List<String> members) {
    final key = 'room:lobby';
    if (_socket.channels.containsKey(key)) {
      final chl = _socket.channels[key]!;
      return chl.push('create:room', {
        'options': {
          'room_name': roomName,
          'room_description': roomDescription,
          'is_secret': isSecret
        },
        'team': tenant,
        'profile_id': profileID,
        'members': [profileID] + members
      });
    } else {
      _log.severe('Channel $key not found!');
      throw Exception('Channel $key not found!');
    }
  }

  Push? createConversation(profileID, topic, isSecret, members) {
    final key = 'conversation:lobby';
    if (_socket.channels.containsKey(key)) {
      final chl = _socket.channels[key]!;
      return chl.push('create:conversation', {
        'options': {'topic': topic, 'is_secret': isSecret},
        'team': tenant,
        'profile_id': profileID,
        'members': [profileID] + members
      });
    } else {
      _log.severe('Channel $key not found!');
      throw Exception('Channel $key not found!');
    }
  }

  Push? sendInvitation(String teamName, String profileID, String identifier) {
    final key = 'team:invite';
    if (_socket.channels.containsKey(key)) {
      final chl = _socket.channels[key]!;
      return chl.push('invite:user', {
        'identifier': identifier,
        'team_name': teamName,
        'profile_id': profileID
      });
    } else {
      var chl = joinChannel(key);
      return chl.push('invite:user', {
        'identifier': identifier,
        'team_name': teamName,
        'profile_id': profileID
      });
    }
  }

  void disconnect() {
    _socket.close();
  }

  bool isConnected() {
    return _connected;
  }
}

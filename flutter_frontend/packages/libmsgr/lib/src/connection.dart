import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/telemetry/socket_telemetry.dart';
import 'package:libmsgr/src/typedefs.dart';
import 'package:libmsgr/src/utils/events.dart';
import 'package:libmsgr_core/libmsgr_core.dart';
import 'package:logging/logging.dart';
import 'package:phoenix_socket/phoenix_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MsgrConnection {
  late PhoenixSocket _socket;
  late PhoenixPresence _presence;
  late PhoenixChannel userChannel;
  final ReduxDispatchCallback dispatchFn;
  final String tenant;
  final String userID;
  final String? _accessToken;
  bool _connected = false;
  NoiseHandshakeResult? _noiseHandshake;

  final Logger _log = Logger('MsgrConnection');
  final IDelegate<String> connectDelegate = Delegate();
  final List<PhoenixChannel> _connectedChannels = [];

  MsgrConnection(String serverUrl, Map<String, String> params, this.tenant,
      this.userID, this.dispatchFn)
      : _accessToken = params['token'] {
    // If NOISE is enabled, we'll create the socket later after handshake
    if (!MsgrConstants.useNoiseProtocol) {
      _socket = PhoenixSocket(serverUrl,
          socketOptions: PhoenixSocketOptions(params: params));
    }
  }

  List<PhoenixChannel> get connectedChannels => _connectedChannels;

  connect() async {
    // Perform NOISE handshake if enabled
    if (MsgrConstants.useNoiseProtocol) {
      await _performNoiseHandshake();
      await _createNoiseSocket();
    }

    await _socket.connect();
    _socket.errorStream.listen(_handleError);
    _socket.closeStream.listen(_handleDisconnect);
    _socket.openStream.listen(_handleConnect);
    /*_socket.streamForTopic('room:lobby').listen((onData) {
      _log.info('ondata: $onData');
    });*/
  }

  /// Perform NOISE protocol handshake with the gateway
  Future<void> _performNoiseHandshake() async {
    _log.info('Performing NOISE handshake with ${MsgrConstants.noiseGatewayUrl}');

    final psk = base64.decode(MsgrConstants.noiseDevPsk);
    final handshakeService = NoiseHandshakeService(
      gatewayUrl: MsgrConstants.noiseGatewayUrl,
      psk: Uint8List.fromList(psk),
    );

    _noiseHandshake = await handshakeService.performHandshake();

    _log.info('NOISE handshake completed. Session: ${_noiseHandshake!.sessionId}');
  }

  /// Create PhoenixSocket with NOISE-encrypted WebSocket channel
  Future<void> _createNoiseSocket() async {
    if (_noiseHandshake == null) {
      throw StateError('NOISE handshake must be performed before creating socket');
    }

    final serverUrl = ServerResolver.getTeamWebSocketServer(tenant);

    _log.info('Creating NOISE-encrypted socket to $serverUrl');

    // Pre-create the NOISE WebSocket channel
    // PhoenixSocket will call the factory synchronously, but we already have
    // the channel ready from the handshake
    NoiseWebSocketChannel? preCreatedChannel;

    WebSocketChannel Function(Uri) channelFactory = (Uri uri) {
      if (preCreatedChannel != null) {
        final channel = preCreatedChannel;
        preCreatedChannel = null; // Use it only once
        return channel!;
      }
      throw StateError('NOISE WebSocket channel was not pre-created');
    };

    // Create the channel asynchronously before PhoenixSocket tries to use it
    preCreatedChannel = await NoiseWebSocketChannel.connect(
      url: serverUrl,
      sessionToken: _noiseHandshake!.sessionToken,
      sendCipher: _noiseHandshake!.sendCipher,
      receiveCipher: _noiseHandshake!.receiveCipher,
    );

    _socket = PhoenixSocket(
      serverUrl,
      socketOptions: PhoenixSocketOptions(params: {'token': _accessToken ?? ''}),
      webSocketChannelFactory: channelFactory,
    );
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
    final repos = LibMsgr().repositoryFactory.getRepositories(tenant);
    await repos.messageRepository.onConnectionChanged(isConnected: true);
    unawaited(_replayPendingMessages());
  }

  void _handleDisconnect(event) {
    _log.info('[-] Socket disconnected! event: ${event.toString()}');
    _connected = false;
    final repos = LibMsgr().repositoryFactory.getRepositories(tenant);
    unawaited(repos.messageRepository.onConnectionChanged(isConnected: false));
  }

  Future<void> _replayPendingMessages() async {
    final repos = LibMsgr().repositoryFactory.getRepositories(tenant);
    await repos.messageRepository.processPendingQueue();
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
    if (!_connected) {
      _log.warning('Socket disconnected; queuing message ${msg.id} for retry');
      SocketTelemetry.instance.messageRetryScheduled(
        conversationId: msg.conversationID ?? msg.roomID ?? destID,
        messageId: msg.id,
        metadata: {
          'topic': key,
          'reason': 'socket_disconnected',
        },
      );
      return null;
    }

    if (!_socket.channels.containsKey(key)) {
      _log.warning('Channel $key not found; queuing message ${msg.id} for retry');
      SocketTelemetry.instance.messageRetryScheduled(
        conversationId: msg.conversationID ?? msg.roomID ?? destID,
        messageId: msg.id,
        metadata: {
          'topic': key,
          'reason': 'channel_missing',
        },
      );
      return null;
    }

    final chl = _socket.channels[key]!;
    SocketTelemetry.instance.messageSent(
      conversationId: msg.conversationID ?? msg.roomID ?? destID,
      messageId: msg.id,
      metadata: {'topic': key},
    );

    final push = chl.push('create:msg', msg.toMap());
    push?.future.then((response) {
      final repos = LibMsgr().repositoryFactory.getRepositories(tenant);
      repos.messageRepository.updateDeliveryStatus(
        msg.id,
        MessageDeliveryStatus.delivered,
        isServerAck: true,
      );
      SocketTelemetry.instance.messageAcknowledged(
        conversationId: msg.conversationID ?? msg.roomID ?? destID,
        messageId: msg.id,
        metadata: {
          'topic': key,
          'status': response?.status ?? 'ok',
        },
      );
    }).catchError((error) {
      final repos = LibMsgr().repositoryFactory.getRepositories(tenant);
      repos.messageRepository.updateDeliveryStatus(
        msg.id,
        MessageDeliveryStatus.failed,
      );
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

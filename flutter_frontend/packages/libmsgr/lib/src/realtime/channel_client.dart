import 'dart:async';

import 'package:logging/logging.dart';
import 'package:phoenix_socket/phoenix_socket.dart';

/// Callback signature for channel events.
typedef RealtimeEventCallback = void Function(
    String topic, String event, Map<String, dynamic> payload);

/// Callback signature for presence updates.
typedef RealtimePresenceCallback = void Function(
    String topic, Map<String, dynamic> presenceState);

/// Real-time client using Phoenix Channels over WebSocket.
///
/// Pure Dart -- works in CLI, bot, TUI, and Flutter.
class MsgrRealtimeClient {
  MsgrRealtimeClient({
    required this.wsUrl,
    required this.accountId,
    required this.profileId,
    this.sessionId,
    this.token,
  });

  final String wsUrl;
  final String accountId;
  final String profileId;
  final String? sessionId;

  /// JWT access token. When set, sent as `token` connect param for
  /// server-side JWT authentication (preferred over account_id/profile_id).
  String? token;

  PhoenixSocket? _socket;
  final Map<String, PhoenixChannel> _channels = {};
  final Map<String, StreamSubscription> _subscriptions = {};
  final Logger _log = Logger('MsgrRealtimeClient');

  /// Fired for every event on every joined topic.
  RealtimeEventCallback? onEvent;

  /// Fired when presence state changes on a topic.
  RealtimePresenceCallback? onPresence;

  /// Fired when the socket disconnects.
  void Function()? onDisconnect;

  /// Fired when the socket reconnects.
  void Function()? onReconnect;

  /// Connect to Phoenix WebSocket.
  Future<void> connect() async {
    final params = <String, String>{
      'account_id': accountId,
      'profile_id': profileId,
    };
    if (token != null) {
      params['token'] = token!;
    }
    if (sessionId != null) {
      params['session_id'] = sessionId!;
    }

    _socket = PhoenixSocket(
      wsUrl,
      socketOptions: PhoenixSocketOptions(
        dynamicParams: () async => {
          'account_id': accountId ?? '',
          'profile_id': profileId ?? '',
          if (token != null) 'token': token!,
          if (sessionId != null) 'session_id': sessionId!,
        },
      ),
    );

    _socket!.closeStream.listen((_) {
      _log.info('WebSocket disconnected');
      onDisconnect?.call();
    });

    _socket!.openStream.listen((_) {
      _log.info('WebSocket connected');
      onReconnect?.call();
    });

    _socket!.errorStream.listen((error) {
      _log.warning('WebSocket error: $error');
    });

    await _socket!.connect();
    _log.info('Connected to $wsUrl');
  }

  /// Join a Phoenix channel topic (e.g. "channel:lobby", "conversation:abc").
  ///
  /// Returns the [PhoenixChannel] for advanced usage.
  Future<PhoenixChannel> join(String topic,
      {Map<String, dynamic>? payload}) async {
    if (_channels.containsKey(topic)) {
      return _channels[topic]!;
    }

    final channel =
        _socket!.addChannel(topic: topic, parameters: payload ?? {});
    final push = channel.join();
    await push.future;
    _channels[topic] = channel;

    // Wire up event listener.
    final sub = channel.messages.listen((msg) {
      onEvent?.call(
        topic,
        msg.event.value,
        msg.payload ?? {},
      );
    });
    _subscriptions[topic] = sub;

    _log.fine('Joined topic: $topic');
    return channel;
  }

  /// Leave a previously joined topic.
  Future<void> leave(String topic) async {
    await _subscriptions[topic]?.cancel();
    _subscriptions.remove(topic);
    _channels[topic]?.leave();
    _channels.remove(topic);
    _log.fine('Left topic: $topic');
  }

  /// Push an event to a topic and wait for the reply.
  Future<Map<String, dynamic>> push(
    String topic,
    String event,
    Map<String, dynamic> payload,
  ) async {
    final channel = _channels[topic];
    if (channel == null) {
      throw StateError('Not joined to topic: $topic');
    }

    final pushObj = channel.push(event, payload);
    if (pushObj == null) {
      throw StateError('Failed to push event "$event" to "$topic"');
    }

    final reply = await pushObj.future;
    return reply.response;
  }

  /// Get a joined channel by topic, or null if not joined.
  PhoenixChannel? getChannel(String topic) => _channels[topic];

  /// All currently joined topic names.
  Set<String> get joinedTopics => Set.unmodifiable(_channels.keys);

  /// Whether the socket is currently connected.
  bool get isConnected => _socket?.isConnected ?? false;

  /// Disconnect and clean up all channels.
  void disconnect() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();

    for (final ch in _channels.values) {
      ch.leave();
    }
    _channels.clear();

    _socket?.close();
    _socket = null;
    _log.info('Disconnected');
  }
}

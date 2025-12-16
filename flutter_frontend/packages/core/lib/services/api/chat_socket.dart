import 'dart:async';

import 'package:messngr/config/backend_environment.dart';
import 'package:messngr/features/chat/models/chat_message.dart';
import 'package:messngr/features/chat/models/reaction_aggregate.dart';
import 'package:messngr/services/api/chat_api.dart';
import 'package:messngr/services/api/chat_realtime_event.dart';
import 'package:phoenix_socket/phoenix_socket.dart';

/// Abstraksjon for realtime-klient slik at view-modellen kan stubbes i tester.
abstract class ChatRealtime {
  /// Strøm av typed realtime events.
  Stream<ChatRealtimeEvent> get events;

  /// Strøm av meldinger som kommer fra serveren.
  Stream<ChatMessage> get messages;

  /// Om forbindelsen er aktiv.
  bool get isConnected;

  /// Etabler en forbindelse for en gitt samtale.
  Future<void> connect({
    required AccountIdentity identity,
    required String conversationId,
  });

  /// Send en melding over sanntidskanalen.
  Future<ChatMessage> send(String body);

  /// Marker at brukeren begynner å skrive.
  Future<void> startTyping({String? threadId});

  /// Marker at brukeren stopper å skrive.
  Future<void> stopTyping({String? threadId});

  /// Marker en melding som lest.
  Future<void> markRead(String messageId);

  /// Legg til en reaksjon på en melding.
  Future<void> addReaction(
    String messageId,
    String emoji, {
    Map<String, dynamic>? metadata,
  });

  /// Fjern en reaksjon fra en melding.
  Future<void> removeReaction(String messageId, String emoji);

  /// Fest en melding i samtalen.
  Future<void> pinMessage(
    String messageId, {
    Map<String, dynamic>? metadata,
  });

  /// Løsne en festet melding.
  Future<void> unpinMessage(String messageId);

  /// Koble fra.
  Future<void> disconnect();

  /// Rydd opp i ressurser.
  Future<void> dispose();
}

/// Feiltilstand for sanntidsklienten.
class ChatSocketException implements Exception {
  ChatSocketException(this.message, [this.details]);

  final String message;
  final Object? details;

  @override
  String toString() =>
      'ChatSocketException(message: $message, details: $details)';
}

/// Implementasjon som bruker Phoenix Channels over WebSocket.
class ChatSocket implements ChatRealtime {
  ChatSocket({PhoenixSocket Function(String endpoint)? socketFactory})
      : _socketFactory = socketFactory;

  static const _connectTimeout = Duration(seconds: 15);

  final PhoenixSocket Function(String endpoint)? _socketFactory;
  final StreamController<ChatMessage> _messagesController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<ChatRealtimeEvent> _eventController =
      StreamController<ChatRealtimeEvent>.broadcast();

  PhoenixSocket? _socket;
  PhoenixChannel? _channel;
  StreamSubscription<Message>? _subscription;
  bool _isConnected = false;
  bool _disposed = false;
  String? _conversationId;
  bool _intentionalDisconnect = false;
  bool _allowReconnect = false;
  StreamSubscription<PhoenixSocketOpenEvent>? _openSubscription;
  StreamSubscription<PhoenixSocketCloseEvent>? _closeSubscription;
  StreamSubscription<PhoenixSocketErrorEvent>? _errorSubscription;

  @override
  Stream<ChatRealtimeEvent> get events => _eventController.stream;

  @override
  Stream<ChatMessage> get messages => _messagesController.stream;

  @override
  bool get isConnected => _isConnected && !_disposed;

  void _emitConnectionState(ChatConnectionState state, {Object? error}) {
    if (_eventController.isClosed) {
      return;
    }
    _eventController.add(ChatConnectionEvent(state, error: error));
  }

  @override
  Future<void> connect({
    required AccountIdentity identity,
    required String conversationId,
  }) async {
    if (_disposed) {
      throw StateError('ChatSocket er allerede lukket.');
    }

    if (_isConnected && _conversationId == conversationId) {
      return;
    }

    await disconnect();

    _intentionalDisconnect = false;
    _emitConnectionState(ChatConnectionState.connecting);

    final endpoint = _buildEndpoint();
    final socket = _socketFactory?.call(endpoint) ?? PhoenixSocket(endpoint);
    _socket = socket;
    _bindSocketLifecycle(socket);

    try {
      await socket.connect().timeout(_connectTimeout);
    } catch (error) {
      await _cleanupSocketLifecycle();
      _socket = null;
      socket.dispose();
      _emitConnectionState(ChatConnectionState.disconnected, error: error);
      throw ChatSocketException('Klarte ikke å koble til sanntidsserver.', error);
    }

    final channel = socket.addChannel(
      topic: 'conversation:$conversationId',
      parameters: {
        'account_id': identity.accountId,
        'profile_id': identity.profileId,
        'noise_session': identity.noiseToken,
      },
    );

    final joinPush = channel.join();
    joinPush
      ..onReply('ok', (response) {
        if (_disposed) return;
        _allowReconnect = true;
        _isConnected = true;
        _emitConnectionState(ChatConnectionState.connected);
      })
      ..onReply('error', (response) {
        if (_disposed) return;
        _isConnected = false;
        if (!_intentionalDisconnect) {
          _emitConnectionState(
            ChatConnectionState.reconnecting,
            error: response.response ?? response.status,
          );
        }
      })
      ..onReply('timeout', (response) {
        if (_disposed) return;
        _isConnected = false;
        if (!_intentionalDisconnect) {
          _emitConnectionState(
            ChatConnectionState.reconnecting,
            error: response.response ?? response.status,
          );
        }
      });

    final joinResponse = await joinPush.future;
    if (!joinResponse.isOk) {
      await _cleanupSocketLifecycle();
      socket.dispose();
      throw ChatSocketException(
        'Klarte ikke å knytte til samtalen.',
        joinResponse.response,
      );
    }

    _channel = channel;
    _conversationId = conversationId;
    _isConnected = true;
    _allowReconnect = true;

    _emitConnectionState(ChatConnectionState.connected);

    await _subscription?.cancel();
    _subscription = channel.messages.listen(
      _handleMessage,
      onError: _handleChannelError,
      onDone: _handleChannelDone,
    );
  }

  @override
  Future<ChatMessage> send(String body) async {
    final channel = _channel;
    if (!_isConnected || channel == null) {
      throw ChatSocketException('Samtalen er ikke tilkoblet.');
    }

    final push = channel.push('message:create', {'body': body});

    try {
      final response = await push.future;

      if (response.isOk) {
        final data = _extractMessagePayload(response.response);
        if (data != null) {
          return ChatMessage.fromJson(data);
        }

        throw ChatSocketException(
            'Uventet svar fra server.', response.response);
      }

      if (response.isError) {
        throw ChatSocketException('Meldingen ble avvist.', response.response);
      }

      throw ChatSocketException('Meldingen timet ut.', response.response);
    } on ChannelTimeoutException catch (error) {
      throw ChatSocketException('Meldingen timet ut.', error);
    }
  }

  @override
  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _allowReconnect = false;
    _isConnected = false;
    _conversationId = null;

    await _subscription?.cancel();
    _subscription = null;

    await _cleanupSocketLifecycle();

    if (_channel != null) {
      try {
        await _channel!.leave().future;
      } catch (_) {
        // Ignorer - typisk hvis sokkelen allerede er stengt.
      }
      _channel!.close();
      _channel = null;
    }

    final socket = _socket;
    _socket = null;
    socket?.close();
    socket?.dispose();

    _emitConnectionState(ChatConnectionState.disconnected);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _intentionalDisconnect = true;
    _allowReconnect = false;
    await disconnect();
    await _messagesController.close();
    await _eventController.close();
    _disposed = true;
  }

  @override
  Future<void> startTyping({String? threadId}) async {
    final channel = _requireChannel();
    final payload = <String, dynamic>{};
    if (threadId != null) {
      payload['thread_id'] = threadId;
    }

    channel.push('typing:start', payload);
  }

  @override
  Future<void> stopTyping({String? threadId}) async {
    final channel = _requireChannel();
    final payload = <String, dynamic>{};
    if (threadId != null) {
      payload['thread_id'] = threadId;
    }

    channel.push('typing:stop', payload);
  }

  @override
  Future<void> markRead(String messageId) async {
    await _pushExpectOk('message:read', {'message_id': messageId});
  }

  @override
  Future<void> addReaction(
    String messageId,
    String emoji, {
    Map<String, dynamic>? metadata,
  }) async {
    await _pushExpectOk('reaction:add', {
      'message_id': messageId,
      'emoji': emoji,
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
    });
  }

  @override
  Future<void> removeReaction(String messageId, String emoji) async {
    await _pushExpectOk('reaction:remove', {
      'message_id': messageId,
      'emoji': emoji,
    });
  }

  @override
  Future<void> pinMessage(
    String messageId, {
    Map<String, dynamic>? metadata,
  }) async {
    await _pushExpectOk('message:pin', {
      'message_id': messageId,
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
    });
  }

  @override
  Future<void> unpinMessage(String messageId) async {
    await _pushExpectOk('message:unpin', {
      'message_id': messageId,
    });
  }

  void _handleMessage(Message message) {
    final event = message.event.value;
    final payload = message.payload;

    switch (event) {
      case 'message_created':
      case 'message_updated':
        final data = _extractMessagePayload(payload);
        if (data != null && !_eventController.isClosed) {
          final chatMessage = ChatMessage.fromJson(data);
          if (!_messagesController.isClosed) {
            _messagesController.add(chatMessage);
          }
          _eventController.add(ChatMessageEvent(
            chatMessage,
            kind: event == 'message_updated'
                ? ChatMessageEventKind.updated
                : ChatMessageEventKind.created,
          ));
        }
        break;
      case 'message_deleted':
        final map = _ensureMap(payload);
        final messageId = map['message_id'] as String?;
        if (messageId != null && !_eventController.isClosed) {
          _eventController.add(
            ChatMessageDeletedEvent(
              messageId: messageId,
              deletedAt: _parseDate(map['deleted_at']),
            ),
          );
        }
        break;
      case 'reaction_added':
      case 'reaction_removed':
        final map = _ensureMap(payload);
        final messageId = map['message_id'] as String?;
        final emoji = map['emoji'] as String?;
        final profileId = map['profile_id'] as String?;
        if (messageId != null &&
            emoji != null &&
            profileId != null &&
            !_eventController.isClosed) {
          final aggregates = <ReactionAggregate>[];
          final rawAggregates = map['aggregates'];
          if (rawAggregates is List) {
            for (final entry in rawAggregates) {
              final aggregateMap = _ensureMap(entry);
              if (aggregateMap.isNotEmpty) {
                aggregates.add(
                  ReactionAggregate.fromJson(aggregateMap),
                );
              }
            }
          }

          final metadata = _mapOrEmpty(map['metadata']);

          _eventController.add(
            ChatReactionEvent(
              messageId: messageId,
              emoji: emoji,
              profileId: profileId,
              isAddition: event == 'reaction_added',
              aggregates: aggregates,
              metadata: metadata,
            ),
          );
        }
        break;
      case 'message_pinned':
      case 'message_unpinned':
        final map = _ensureMap(payload);
        final messageId = map['message_id'] as String?;
        final pinnedById = map['pinned_by_id'] as String?;
        if (messageId != null &&
            pinnedById != null &&
            !_eventController.isClosed) {
          _eventController.add(
            ChatPinnedEvent(
              messageId: messageId,
              pinnedById: pinnedById,
              pinnedAt: _parseDate(map['pinned_at']) ?? DateTime.now().toUtc(),
              isPinned: event == 'message_pinned',
              metadata: _mapOrEmpty(map['metadata']),
            ),
          );
        }
        break;
      case 'typing_started':
      case 'typing_stopped':
        final map = _ensureMap(payload);
        final profileId = map['profile_id'] as String?;
        final profileName = map['profile_name'] as String?;
        if (profileId != null &&
            profileName != null &&
            !_eventController.isClosed) {
          _eventController.add(
            ChatTypingEvent(
              profileId: profileId,
              profileName: profileName,
              isTyping: event == 'typing_started',
              threadId: map['thread_id'] as String?,
              expiresAt: _parseDate(map['expires_at']),
            ),
          );
        }
        break;
      case 'message_read':
        final map = _ensureMap(payload);
        final profileId = map['profile_id'] as String?;
        final messageId = map['message_id'] as String?;
        if (profileId != null &&
            messageId != null &&
            !_eventController.isClosed) {
          _eventController.add(
            ChatReadEvent(
              profileId: profileId,
              messageId: messageId,
              readAt: _parseDate(map['read_at']),
            ),
          );
        }
        break;
      default:
        break;
    }
  }

  void _handleChannelError(Object error, StackTrace _) {
    if (_disposed) return;
    _isConnected = false;
    if (_allowReconnect && !_intentionalDisconnect) {
      _emitConnectionState(ChatConnectionState.reconnecting, error: error);
    } else {
      _emitConnectionState(ChatConnectionState.disconnected, error: error);
    }
  }

  void _handleChannelDone() {
    if (_disposed) return;
    _isConnected = false;
    if (_allowReconnect && !_intentionalDisconnect) {
      _emitConnectionState(ChatConnectionState.reconnecting);
    } else {
      _emitConnectionState(ChatConnectionState.disconnected);
    }
  }

  Map<String, dynamic>? _extractMessagePayload(dynamic payload) {
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload as Map);
      final nested = map['data'];
      if (nested is Map) {
        return Map<String, dynamic>.from(nested as Map);
      }
      return map;
    }
    return null;
  }

  String _buildEndpoint() {
    final apiUri = BackendEnvironment.instance.apiBaseUri;
    final isSecure = apiUri.scheme == 'https';

    final socketUri = Uri(
      scheme: isSecure ? 'wss' : 'ws',
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
      path: '/socket/websocket',
      queryParameters: const {'vsn': '2.0.0'},
    );

    return socketUri.toString();
  }

  void _bindSocketLifecycle(PhoenixSocket socket) {
    _openSubscription?.cancel();
    _closeSubscription?.cancel();
    _errorSubscription?.cancel();

    _openSubscription = socket.openStream.listen((_) {
      if (_disposed || _intentionalDisconnect) {
        return;
      }
      if (_allowReconnect && !_isConnected) {
        _emitConnectionState(ChatConnectionState.reconnecting);
      }
    });

    _closeSubscription = socket.closeStream.listen((event) {
      if (_disposed) return;
      _isConnected = false;
      _emitConnectionState(ChatConnectionState.disconnected, error: event);
      if (_allowReconnect && !_intentionalDisconnect) {
        _emitConnectionState(ChatConnectionState.reconnecting, error: event);
      }
    });

    _errorSubscription = socket.errorStream.listen((event) {
      if (_disposed || !_allowReconnect || _intentionalDisconnect) {
        return;
      }
      _emitConnectionState(ChatConnectionState.reconnecting, error: event);
    });
  }

  Future<void> _cleanupSocketLifecycle() async {
    await _openSubscription?.cancel();
    await _closeSubscription?.cancel();
    await _errorSubscription?.cancel();
    _openSubscription = null;
    _closeSubscription = null;
    _errorSubscription = null;
  }

  PhoenixChannel _requireChannel() {
    final channel = _channel;
    if (!_isConnected || channel == null) {
      throw ChatSocketException('Samtalen er ikke tilkoblet.');
    }
    return channel;
  }

  Future<void> _pushExpectOk(String event, Map<String, dynamic> payload) async {
    final channel = _requireChannel();
    final push = channel.push(event, payload);

    try {
      final response = await push.future;
      if (response.isError) {
        throw ChatSocketException('Handling ble avvist.', response.response);
      }
      if (!response.isOk) {
        throw ChatSocketException(
            'Uventet svar fra server.', response.response);
      }
    } on ChannelTimeoutException catch (error) {
      throw ChatSocketException('Handlingen timet ut.', error);
    }
  }

  Map<String, dynamic> _ensureMap(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      return Map<String, dynamic>.from(payload);
    }
    if (payload is Map) {
      return Map<String, dynamic>.from(
        payload.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _mapOrEmpty(dynamic payload) {
    if (payload == null) {
      return const <String, dynamic>{};
    }
    return _ensureMap(payload);
  }

  DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

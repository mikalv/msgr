import 'dart:async';

import 'package:messngr/config/backend_environment.dart';
import 'package:messngr/features/chat/models/chat_message.dart';
import 'package:messngr/services/api/chat_api.dart';
import 'package:phoenix_socket/phoenix_socket.dart';

/// Abstraksjon for realtime-klient slik at view-modellen kan stubbes i tester.
abstract class ChatRealtime {
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
  String toString() => 'ChatSocketException(message: $message, details: $details)';
}

/// Implementasjon som bruker Phoenix Channels over WebSocket.
class ChatSocket implements ChatRealtime {
  ChatSocket({PhoenixSocket Function(String endpoint)? socketFactory})
      : _socketFactory = socketFactory;

  final PhoenixSocket Function(String endpoint)? _socketFactory;
  final StreamController<ChatMessage> _messagesController =
      StreamController<ChatMessage>.broadcast();

  PhoenixSocket? _socket;
  PhoenixChannel? _channel;
  StreamSubscription<Message>? _subscription;
  bool _isConnected = false;
  bool _disposed = false;
  String? _conversationId;

  @override
  Stream<ChatMessage> get messages => _messagesController.stream;

  @override
  bool get isConnected => _isConnected && !_disposed;

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

    final endpoint = _buildEndpoint();
    final socket = _socketFactory?.call(endpoint) ?? PhoenixSocket(endpoint);

    await socket.connect();

    final channel = socket.addChannel(
      topic: 'conversation:$conversationId',
      parameters: {
        'account_id': identity.accountId,
        'profile_id': identity.profileId,
      },
    );

    final joinResponse = await channel.join().future;
    if (!joinResponse.isOk) {
      socket.dispose();
      throw ChatSocketException(
        'Klarte ikke å knytte til samtalen.',
        joinResponse.response,
      );
    }

    _socket = socket;
    _channel = channel;
    _conversationId = conversationId;
    _isConnected = true;

    _subscription = channel.messages.listen(
      _handleMessage,
      onError: (error, stackTrace) {
        // Propagerer ikke videre, men logger kan legges på sikt.
      },
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

        throw ChatSocketException('Uventet svar fra server.', response.response);
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
    _isConnected = false;
    _conversationId = null;

    await _subscription?.cancel();
    _subscription = null;

    if (_channel != null) {
      try {
        await _channel!.leave().future;
      } catch (_) {
        // Ignorer - typisk hvis sokkelen allerede er stengt.
      }
      _channel = null;
    }

    _socket?.close();
    _socket?.dispose();
    _socket = null;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    await disconnect();
    await _messagesController.close();
    _disposed = true;
  }

  void _handleMessage(Message message) {
    if (message.event.value != 'message_created') {
      return;
    }

    final payload = message.payload;
    final data = _extractMessagePayload(payload);

    if (data != null && !_messagesController.isClosed) {
      _messagesController.add(ChatMessage.fromJson(data));
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
}

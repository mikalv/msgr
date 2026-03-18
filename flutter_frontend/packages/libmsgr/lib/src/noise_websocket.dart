import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:libmsgr/noise_protocol_framework/noise_protocol_framework.dart';
import 'package:logging/logging.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final _log = Logger('NoiseWebSocket');

/// WebSocketChannel that encrypts/decrypts frames using NOISE protocol
class NoiseWebSocketChannel extends StreamChannelMixin implements WebSocketChannel {
  final NoiseWebSocket _noiseWebSocket;
  final Stream _stream;
  final _NoiseWebSocketSink _sink;

  NoiseWebSocketChannel._(this._noiseWebSocket, this._stream, this._sink);

  /// Create a NOISE-encrypted WebSocket channel
  static Future<NoiseWebSocketChannel> connect({
    required String url,
    required String sessionToken,
    required CipherState sendCipher,
    required CipherState receiveCipher,
  }) async {
    final noiseWs = NoiseWebSocket(
      url: url,
      sessionToken: sessionToken,
      sendCipher: sendCipher,
      receiveCipher: receiveCipher,
    );

    await noiseWs.connect();

    final sink = _NoiseWebSocketSink(noiseWs);

    return NoiseWebSocketChannel._(noiseWs, noiseWs.stream, sink);
  }

  @override
  Stream get stream => _stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  String? get protocol => null;

  @override
  int? get closeCode => _noiseWebSocket.readyState == WebSocket.closed ? 1000 : null;

  @override
  String? get closeReason => null;

  @override
  Future<void> get ready => Future.value();
}

/// WebSocketSink that sends encrypted messages
class _NoiseWebSocketSink implements WebSocketSink {
  final NoiseWebSocket _noiseWebSocket;

  _NoiseWebSocketSink(this._noiseWebSocket);

  @override
  void add(event) {
    _noiseWebSocket.send(event);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _log.severe('Error in WebSocket sink: $error', error, stackTrace);
    // Errors are not sent to the remote endpoint, just logged
    // The connection may need to be closed depending on the error
  }

  @override
  Future addStream(Stream stream) async {
    await for (final event in stream) {
      add(event);
    }
  }

  @override
  Future close([int? closeCode, String? closeReason]) async {
    await _noiseWebSocket.close(closeCode, closeReason);
  }

  @override
  Future get done => _noiseWebSocket._doneCompleter.future;
}

/// WebSocket wrapper that encrypts/decrypts frames using NOISE protocol
class NoiseWebSocket {
  final String url;
  final String sessionToken;
  final CipherState _sendCipher;
  final CipherState _receiveCipher;

  WebSocket? _socket;
  final _controller = StreamController<dynamic>.broadcast();
  final _doneCompleter = Completer<void>();
  bool _isClosed = false;

  NoiseWebSocket({
    required this.url,
    required this.sessionToken,
    required CipherState sendCipher,
    required CipherState receiveCipher,
  })  : _sendCipher = sendCipher,
        _receiveCipher = receiveCipher;

  /// Connect to the WebSocket server
  Future<void> connect() async {
    if (_socket != null) {
      _log.warning('WebSocket already connected');
      return;
    }

    _log.info('Connecting to $url with NOISE encryption');

    try {
      _socket = await WebSocket.connect(
        url,
        headers: {
          'Authorization': 'Bearer $sessionToken',
        },
      );

      _log.info('WebSocket connected successfully');

      // Listen to incoming messages
      _socket!.listen(
        _handleIncoming,
        onError: (error) {
          _log.severe('WebSocket error: $error');
          _controller.addError(error);
        },
        onDone: () {
          _log.info('WebSocket connection closed');
          _isClosed = true;
          _controller.close();
          if (!_doneCompleter.isCompleted) {
            _doneCompleter.complete();
          }
        },
      );
    } catch (e) {
      _log.severe('Failed to connect WebSocket: $e');
      _isClosed = true;
      rethrow;
    }
  }

  /// Handle incoming encrypted messages
  void _handleIncoming(dynamic data) {
    try {
      if (data is! List<int>) {
        _log.warning('Received non-binary message: $data');
        return;
      }

      final encrypted = Uint8List.fromList(data);
      _log.fine('Received encrypted frame: ${encrypted.length} bytes');

      // Decrypt with NOISE
      final decrypted = _receiveCipher.decryptWithAd(Uint8List(0), encrypted);
      _log.fine('Decrypted to: ${decrypted.length} bytes');

      // Decode as UTF-8 string (Phoenix channels use text messages)
      final message = utf8.decode(decrypted);
      _log.fine('Decoded message: $message');

      // Forward to listeners
      _controller.add(message);
    } catch (e, stackTrace) {
      _log.severe('Failed to decrypt/decode incoming message: $e', e, stackTrace);
      _controller.addError(e);
    }
  }

  /// Send a message (will be encrypted with NOISE)
  void send(dynamic message) {
    if (_socket == null || _isClosed) {
      throw StateError('WebSocket is not connected');
    }

    try {
      // Encode message to bytes
      final Uint8List plaintext;
      if (message is String) {
        plaintext = Uint8List.fromList(utf8.encode(message));
      } else if (message is List<int>) {
        plaintext = Uint8List.fromList(message);
      } else {
        // Assume it's a JSON-encodable object
        final jsonStr = json.encode(message);
        plaintext = Uint8List.fromList(utf8.encode(jsonStr));
      }

      _log.fine('Encrypting message: ${plaintext.length} bytes');

      // Encrypt with NOISE
      final encrypted = _sendCipher.encryptWithAd(Uint8List(0), plaintext);
      _log.fine('Encrypted to: ${encrypted.length} bytes');

      // Send as binary frame
      _socket!.add(encrypted);
    } catch (e, stackTrace) {
      _log.severe('Failed to encrypt/send message: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Stream of incoming messages (after decryption)
  Stream<dynamic> get stream => _controller.stream;

  /// Close the WebSocket connection
  Future<void> close([int? code, String? reason]) async {
    if (_isClosed) {
      return;
    }

    _log.info('Closing WebSocket connection');
    _isClosed = true;

    await _socket?.close(code, reason);
    await _controller.close();

    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }

  /// Check if WebSocket is connected
  bool get isConnected => _socket != null && !_isClosed;

  /// Get the WebSocket ready state
  int? get readyState => _socket?.readyState;
}

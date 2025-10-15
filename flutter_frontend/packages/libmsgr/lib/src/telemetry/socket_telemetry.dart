import 'dart:async';

import 'package:logging/logging.dart';

class SocketEvent {
  SocketEvent({
    required this.name,
    required this.timestamp,
    this.conversationId,
    this.messageId,
    this.threadId,
    Map<String, Object?>? metadata,
  }) : metadata = Map.unmodifiable(metadata ?? const {});

  final String name;
  final DateTime timestamp;
  final String? conversationId;
  final String? messageId;
  final String? threadId;
  final Map<String, Object?> metadata;
}

class SocketTelemetry {
  SocketTelemetry._();

  static final SocketTelemetry instance = SocketTelemetry._();
  static final Logger _log = Logger('SocketTelemetry');

  final StreamController<SocketEvent> _events = StreamController<SocketEvent>.broadcast();

  Stream<SocketEvent> get events => _events.stream;

  void messageSent({
    String? conversationId,
    String? messageId,
    Map<String, Object?> metadata = const {},
  }) {
    _record(
      name: 'message.sent',
      conversationId: conversationId,
      messageId: messageId,
      metadata: metadata,
    );
  }

  void messageAcknowledged({
    String? conversationId,
    String? messageId,
    Map<String, Object?> metadata = const {},
  }) {
    _record(
      name: 'message.acknowledged',
      conversationId: conversationId,
      messageId: messageId,
      metadata: metadata,
    );
  }

  void typingStarted({
    String? conversationId,
    String? threadId,
    Map<String, Object?> metadata = const {},
  }) {
    _record(
      name: 'typing.started',
      conversationId: conversationId,
      threadId: threadId,
      metadata: metadata,
    );
  }

  void typingStopped({
    String? conversationId,
    String? threadId,
    Map<String, Object?> metadata = const {},
  }) {
    _record(
      name: 'typing.stopped',
      conversationId: conversationId,
      threadId: threadId,
      metadata: metadata,
    );
  }

  void _record({
    required String name,
    String? conversationId,
    String? messageId,
    String? threadId,
    Map<String, Object?> metadata = const {},
  }) {
    final event = SocketEvent(
      name: name,
      timestamp: DateTime.now().toUtc(),
      conversationId: conversationId,
      messageId: messageId,
      threadId: threadId,
      metadata: metadata,
    );
    _log.fine(
        'socket event: $name conversation=$conversationId message=$messageId thread=$threadId metadata=$metadata');
    if (!_events.isClosed) {
      _events.add(event);
    }
  }
}

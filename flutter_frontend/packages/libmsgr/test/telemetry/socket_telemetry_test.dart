import 'dart:async';

import 'package:libmsgr/src/telemetry/socket_telemetry.dart';
import 'package:test/test.dart';

void main() {
  group('SocketTelemetry', () {
    test('emits events for message sent and ack', () async {
      final telemetry = SocketTelemetry.instance;
      final events = <SocketEvent>[];
      final sub = telemetry.events.listen(events.add);

      telemetry.messageSent(conversationId: 'conv-1', messageId: 'msg-1');
      telemetry.messageAcknowledged(
        conversationId: 'conv-1',
        messageId: 'msg-1',
        metadata: {'status': 'ok'},
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      expect(events, hasLength(2));
      expect(events.first.name, 'message.sent');
      expect(events.last.name, 'message.acknowledged');
      expect(events.last.metadata['status'], 'ok');
    });

    test('tracks typing transitions', () async {
      final telemetry = SocketTelemetry.instance;
      final controller = StreamController<SocketEvent>();
      final sub = telemetry.events.listen(controller.add);

      telemetry.typingStarted(conversationId: 'conv-1', threadId: 'root');
      telemetry.typingStopped(conversationId: 'conv-1', threadId: 'root');

      final emitted = await controller.stream.take(2).toList();
      await sub.cancel();
      await controller.close();

      expect(emitted.map((event) => event.name), ['typing.started', 'typing.stopped']);
      expect(emitted.first.threadId, 'root');
    });
  });
}

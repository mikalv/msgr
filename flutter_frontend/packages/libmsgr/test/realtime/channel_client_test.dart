import 'package:test/test.dart';
import 'package:libmsgr/src/realtime/channel_client.dart';

void main() {
  group('MsgrRealtimeClient', () {
    late MsgrRealtimeClient client;

    setUp(() {
      client = MsgrRealtimeClient(
        wsUrl: 'ws://localhost:4000/socket/websocket',
        accountId: 'acc-1',
        profileId: 'prof-1',
      );
    });

    tearDown(() {
      client.disconnect();
    });

    test('stores construction parameters', () {
      expect(client.wsUrl, 'ws://localhost:4000/socket/websocket');
      expect(client.accountId, 'acc-1');
      expect(client.profileId, 'prof-1');
      expect(client.sessionId, isNull);
      expect(client.token, isNull);
    });

    test('accepts optional sessionId and token', () {
      final c = MsgrRealtimeClient(
        wsUrl: 'ws://localhost:4000/socket/websocket',
        accountId: 'acc-2',
        profileId: 'prof-2',
        sessionId: 'sess-42',
        token: 'jwt-token-xyz',
      );
      expect(c.sessionId, 'sess-42');
      expect(c.token, 'jwt-token-xyz');
      c.disconnect();
    });

    test('isConnected is false initially', () {
      expect(client.isConnected, isFalse);
    });

    test('getChannel returns null when not joined', () {
      expect(client.getChannel('channel:lobby'), isNull);
      expect(client.getChannel('conversation:abc'), isNull);
    });

    test('joinedTopics is empty initially', () {
      expect(client.joinedTopics, isEmpty);
    });

    test('onEvent callback can be registered', () {
      var called = false;
      client.onEvent = (topic, event, payload) {
        called = true;
      };
      expect(client.onEvent, isNotNull);
      // Invoke manually to verify the callback type compiles and works
      client.onEvent!('topic', 'event', {'key': 'value'});
      expect(called, isTrue);
    });

    test('onPresence callback can be registered', () {
      var called = false;
      client.onPresence = (topic, presenceState) {
        called = true;
      };
      expect(client.onPresence, isNotNull);
      client.onPresence!('topic', {'user1': {}});
      expect(called, isTrue);
    });

    test('onDisconnect callback can be registered', () {
      var called = false;
      client.onDisconnect = () {
        called = true;
      };
      expect(client.onDisconnect, isNotNull);
      client.onDisconnect!();
      expect(called, isTrue);
    });

    test('onReconnect callback can be registered', () {
      var called = false;
      client.onReconnect = () {
        called = true;
      };
      expect(client.onReconnect, isNotNull);
      client.onReconnect!();
      expect(called, isTrue);
    });

    test('disconnect is safe when not connected', () {
      // Should not throw
      client.disconnect();
      expect(client.isConnected, isFalse);
    });

    test('disconnect can be called multiple times', () {
      client.disconnect();
      client.disconnect();
      expect(client.isConnected, isFalse);
    });

    test('callbacks default to null', () {
      expect(client.onEvent, isNull);
      expect(client.onPresence, isNull);
      expect(client.onDisconnect, isNull);
      expect(client.onReconnect, isNull);
    });
  });
}

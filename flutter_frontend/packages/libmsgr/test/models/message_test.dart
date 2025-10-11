import 'package:flutter_test/flutter_test.dart';
import 'package:libmsgr/src/models/message.dart';

void main() {
  group('MMessage', () {
    final DateTime now = DateTime.now();

    test('should create an instance using MMessage.raw', () {
      final message = MMessage.raw(
        fromProfileID: '123',
        content: 'Hello, world!',
        createdAt: now,
        updatedAt: now,
        conversationID: 'conv1',
      );

      expect(message.fromProfileID, '123');
      expect(message.content, 'Hello, world!');
      expect(message.createdAt, now);
      expect(message.updatedAt, now);
      expect(message.conversationID, 'conv1');
      expect(message.roomID, isNull);
      expect(message.kIsSystemMsg, isFalse);
      expect(message.isServerAck, isTrue);
      expect(message.isMsgRead, isFalse);
    });

    test('should create an instance using MMessage factory', () {
      final message = MMessage(
        fromProfileID: '123',
        content: 'Hello, world!',
        conversationID: 'conv1',
      );

      expect(message.fromProfileID, '123');
      expect(message.content, 'Hello, world!');
      expect(message.conversationID, 'conv1');
      expect(message.roomID, isNull);
      expect(message.kIsSystemMsg, isFalse);
      expect(message.isServerAck, isTrue);
      expect(message.isMsgRead, isFalse);
    });

    test('should convert to and from map', () {
      final message = MMessage.raw(
        fromProfileID: '123',
        content: 'Hello, world!',
        createdAt: now,
        updatedAt: now,
        conversationID: 'conv1',
      );

      final map = message.toMap();
      final fromMap = MMessage.fromMap(map);

      expect(fromMap, message);
    });

    test('should convert to and from json', () {
      final message = MMessage.raw(
        fromProfileID: '123',
        content: 'Hello, world!',
        createdAt: now,
        updatedAt: now,
        conversationID: 'conv1',
      );

      final json = message.toJson();
      final fromJson = MMessage.fromJson(json);

      expect(fromJson, message);
    });

    test('should copy with new values', () {
      final message = MMessage.raw(
        fromProfileID: '123',
        content: 'Hello, world!',
        createdAt: now,
        updatedAt: now,
        conversationID: 'conv1',
      );

      final copiedMessage = message.copyWith(content: 'New content');

      expect(copiedMessage.content, 'New content');
      expect(copiedMessage.fromProfileID, message.fromProfileID);
      expect(copiedMessage.createdAt, message.createdAt);
      expect(copiedMessage.updatedAt, message.updatedAt);
      expect(copiedMessage.conversationID, message.conversationID);
    });

    test('should compare equality and hash code', () {
      final message1 = MMessage.raw(
        fromProfileID: '123',
        content: 'Hello, world!',
        createdAt: now,
        updatedAt: now,
        conversationID: 'conv1',
      );

      final message2 = MMessage.raw(
        fromProfileID: '123',
        content: 'Hello, world!',
        createdAt: now,
        updatedAt: now,
        conversationID: 'conv1',
      );

      expect(message1, message2);
      expect(message1.hashCode, message2.hashCode);
    });

    test(
        'should throw ArgumentError if both conversationID and roomID are null',
        () {
      expect(
        () => MMessage.raw(
          fromProfileID: '123',
          content: 'Hello, world!',
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });
  });
}

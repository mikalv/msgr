import 'package:flutter_test/flutter_test.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/models/conversation.dart';

void main() {
  group('Conversation Model Tests', () {
    final profile = Profile(
        id: '1', uid: '1', username: 'John Doe', insertedAt: '', roles: []);
    final conversation = Conversation(
      id: '123',
      topic: 'Test Topic',
      description: 'Test Description',
      members: ['1'],
      kIsSecret: false,
      createdAt: '2023-10-01T12:00:00Z',
    );

    test('Conversation equality', () {
      final conversation2 = Conversation(
        id: '123',
        topic: 'Test Topic',
        description: 'Test Description',
        members: ['1'],
        kIsSecret: false,
        createdAt: '2023-10-01T12:00:00Z',
      );

      expect(conversation, equals(conversation2));
    });

    test('Conversation inequality', () {
      final profile = Profile(
          id: '2', uid: '2', username: 'janedoe', roles: [], insertedAt: '');
      final conversation2 = Conversation(
        id: '124',
        topic: 'Another Topic',
        description: 'Another Description',
        members: ['1'],
        kIsSecret: true,
        createdAt: '2023-10-02T12:00:00Z',
      );

      expect(conversation, isNot(equals(conversation2)));
    });

    test('Conversation toJson', () {
      final json = conversation.toJson();
      expect(json, {
        'id': '123',
        'topic': 'Test Topic',
        'description': 'Test Description',
        'is_secret': false,
        'inserted_at': '2023-10-01T12:00:00Z',
        'members': [
          Profile(
              id: '1', uid: '1', username: 'johndoe', roles: [], insertedAt: '')
        ],
      });
    });

    test('Conversation fromJson', () {
      final json = {
        'id': '123',
        'topic': 'Test Topic',
        'description': 'Test Description',
        'is_secret': false,
        'inserted_at': '2023-10-01T12:00:00Z',
        'members': ['1'],
      };

      final conversationFromJson = Conversation.fromJson(json);
      expect(conversationFromJson.id, '123');
      expect(conversationFromJson.topic, 'Test Topic');
      expect(conversationFromJson.description, 'Test Description');
      expect(conversationFromJson.kIsSecret, false);
      expect(conversationFromJson.createdAt, '2023-10-01T12:00:00Z');
      expect(conversationFromJson.members, []);
    });

    test('Conversation toString', () {
      final stringRepresentation = conversation.toString();
      expect(stringRepresentation,
          'Conversation{ID: 123, topic: Test Topic, description: Test Description, kIsSecret: false}');
    });
  });
}

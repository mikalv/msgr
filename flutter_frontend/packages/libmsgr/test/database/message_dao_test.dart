import 'package:flutter_test/flutter_test.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/database/daos/message_dao.dart';
import 'package:libmsgr/src/database/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('MessageDao', () {
    late DatabaseService databaseService;
    late MessageDao dao;

    setUp(() async {
      databaseService = DatabaseService();
      await databaseService.initialize();
      dao = MessageDao(databaseService.instance);
    });

    tearDown(() async {
      final path = databaseService.instance.path;
      await databaseService.instance.close();
      await databaseFactory.deleteDatabase(path);
    });

    test('persists and reads back messages for a team', () async {
      final message = MMessage.raw(
        id: 'msg-1',
        content: 'Hello world',
        fromProfileID: 'profile-1',
        conversationID: 'conversation-1',
        roomID: null,
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 1, 0, 1),
      );

      await dao.upsertMessages('team-a', [message]);

      final stored = await dao.getMessagesForTeam('team-a');

      expect(stored, hasLength(1));
      expect(stored.single.id, message.id);
      expect(stored.single.content, message.content);
    });

    test('filters by team name', () async {
      final sharedMessage = MMessage.raw(
        id: 'msg-1',
        content: 'Hello world',
        fromProfileID: 'profile-1',
        conversationID: 'conversation-1',
        roomID: null,
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 1, 0, 1),
      );

      await dao.upsertMessages('team-a', [sharedMessage]);
      await dao.upsertMessages(
        'team-b',
        [sharedMessage.copyWith(id: 'msg-2')],
      );

      final stored = await dao.getMessagesForTeam('team-a');

      expect(stored.map((m) => m.id), ['msg-1']);
    });

    test('deletes messages', () async {
      final message = MMessage.raw(
        id: 'msg-1',
        content: 'Hello world',
        fromProfileID: 'profile-1',
        conversationID: 'conversation-1',
        roomID: null,
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 1, 0, 1),
      );

      await dao.upsertMessages('team-a', [message]);
      await dao.deleteMessages('team-a', ['msg-1']);

      final stored = await dao.getMessagesForTeam('team-a');
      expect(stored, isEmpty);
    });

    test('filters by conversation and room', () async {
      final conversationMessage = MMessage.raw(
        id: 'msg-1',
        content: 'Conversation message',
        fromProfileID: 'profile-1',
        conversationID: 'conversation-1',
        roomID: null,
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 1),
      );
      final roomMessage = MMessage.raw(
        id: 'msg-2',
        content: 'Room message',
        fromProfileID: 'profile-1',
        conversationID: null,
        roomID: 'room-1',
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 1),
      );

      await dao.upsertMessages('team-a', [conversationMessage, roomMessage]);

      final convMessages =
          await dao.getMessagesForConversation('team-a', 'conversation-1');
      final roomMessages = await dao.getMessagesForRoom('team-a', 'room-1');

      expect(convMessages.map((m) => m.id), ['msg-1']);
      expect(roomMessages.map((m) => m.id), ['msg-2']);
    });
  });
}

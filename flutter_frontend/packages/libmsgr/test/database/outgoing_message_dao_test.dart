import 'package:flutter_test/flutter_test.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/database/daos/outgoing_message_dao.dart';
import 'package:libmsgr/src/database/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('OutgoingMessageDao', () {
    late DatabaseService databaseService;
    late OutgoingMessageDao dao;
    late MMessage sampleMessage;

    setUp(() async {
      databaseService = DatabaseService();
      await databaseService.initialize();
      dao = OutgoingMessageDao(databaseService.instance);
      sampleMessage = MMessage.raw(
        id: 'msg-1',
        content: 'Hello world',
        fromProfileID: 'profile-1',
        conversationID: 'conversation-1',
        roomID: null,
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 1, 0, 1),
        isServerAck: false,
      );
    });

    tearDown(() async {
      final path = databaseService.instance.path;
      await databaseService.instance.close();
      await databaseFactory.deleteDatabase(path);
    });

    test('enqueues and retrieves pending messages', () async {
      final outgoing = OutgoingMessage(
        message: sampleMessage,
        topic: 'team.conversation-1',
      );

      await dao.enqueue('team-a', outgoing);

      final pending = await dao.getPending('team-a');

      expect(pending, hasLength(1));
      expect(pending.single.message.id, sampleMessage.id);
      expect(pending.single.topic, outgoing.topic);
    });

    test('tracks attempts and deletions', () async {
      final outgoing = OutgoingMessage(
        message: sampleMessage,
        topic: 'team.conversation-1',
      );

      await dao.enqueue('team-a', outgoing);
      await dao.markAttempt(
        'team-a',
        sampleMessage.id,
        attemptedAt: DateTime.utc(2024, 2, 1),
        attemptCount: 2,
      );

      var pending = await dao.getPending('team-a');
      expect(pending.single.attemptCount, 2);
      expect(pending.single.lastAttemptAt, DateTime.utc(2024, 2, 1));

      await dao.delete('team-a', sampleMessage.id);
      pending = await dao.getPending('team-a');
      expect(pending, isEmpty);
    });
  });
}

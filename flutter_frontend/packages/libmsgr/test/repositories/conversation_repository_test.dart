import 'package:flutter_test/flutter_test.dart';
import 'package:libmsgr/src/models/conversation.dart';
import 'package:libmsgr/src/repositories/conversation_repository.dart';
import 'package:mockito/mockito.dart';
import 'package:logging/logging.dart';

class MockConversation extends Mock implements Conversation {}

void main() {
  group('ConversationRepository', () {
    late ConversationRepository repository;

    setUp(() {
      repository = ConversationRepository(teamName: '');
    });

    test('should log startup message', () {
      final log = Logger('ConversationRepository');
      final logRecords = <LogRecord>[];
      log.onRecord.listen(logRecords.add);

      repository = ConversationRepository(teamName: '');

      expect(logRecords, isNotEmpty);
      expect(logRecords.first.message, 'ConversationRepository is starting up');
    });

    test('getItem should return a Conversation', () async {
      final conversation = await repository.getItem(
        teamID: 'team1',
        teamAccessToken: 'token1',
      );

      expect(conversation, isA<Conversation>());
    });

    test('listItems should return a list of Conversations', () async {
      final conversations = await repository.listItems(
        teamID: 'team1',
        teamAccessToken: 'token1',
      );

      expect(conversations, isA<List<Conversation>>());
      expect(conversations, isEmpty);
    });

    test('listMyRooms should return a list of Conversations', () async {
      final conversations = await repository.listMyRooms('team1');

      expect(conversations, isA<List<Conversation>>());
      expect(conversations, isEmpty);
    });

    test('fillLocalCache should notify observers', () {
      final conversations = [MockConversation(), MockConversation()];

      repository.fillLocalCache(conversations);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/features/chat/models/chat_thread.dart';

void main() {
  group('ChatThread', () {
    test('parses kind and topic from json', () {
      final thread = ChatThread.fromJson({
        'id': 'abc',
        'kind': 'channel',
        'topic': '#design',
        'participants': [
          {
            'profile': {'name': 'Kari'}
          },
        ],
      });

      expect(thread.kind, ChatThreadKind.channel);
      expect(thread.topic, '#design');
      expect(thread.displayName, '#design');
    });

    test('falls back to participant names when no topic', () {
      final thread = ChatThread.fromJson({
        'id': 'def',
        'kind': 'group',
        'participants': [
          {
            'profile': {'name': 'Per'}
          },
          {
            'profile': {'name': 'Lise'}
          },
        ],
      });

      expect(thread.kind, ChatThreadKind.group);
      expect(thread.displayName, 'Per, Lise');
    });
  });
}

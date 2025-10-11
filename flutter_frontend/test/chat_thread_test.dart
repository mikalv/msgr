import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/features/chat/models/chat_thread.dart';

void main() {
  group('ChatThread', () {
    test('parses kind and topic from json', () {
      final thread = ChatThread.fromJson({
        'id': 'abc',
        'kind': 'channel',
        'topic': '#design',
        'structure_type': 'project',
        'visibility': 'team',
        'participants': [
          {
            'profile': {'name': 'Kari'}
          },
        ],
      });

      expect(thread.kind, ChatThreadKind.channel);
      expect(thread.topic, '#design');
      expect(thread.displayName, '#design');
      expect(thread.structureType, ChatStructureType.project);
      expect(thread.visibility, ChatVisibility.team);
    });

    test('falls back to participant names when no topic', () {
      final thread = ChatThread.fromJson({
        'id': 'def',
        'kind': 'group',
        'structure_type': 'family',
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
      expect(thread.structureType, ChatStructureType.family);
      expect(thread.visibility, ChatVisibility.private);
    });

    test('parses hidden channel visibility aliases', () {
      final thread = ChatThread.fromJson({
        'id': 'ghi',
        'kind': 'channel',
        'topic': '#ops',
        'visibility': 'hidden',
      });

      expect(thread.visibility, ChatVisibility.private);
    });
  });
}

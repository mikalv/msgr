import 'package:flutter_test/flutter_test.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/models/conversation.dart';

void main() {
  group('Conversation', () {
    final createdAt = DateTime.utc(2023, 10, 1, 12);
    final updatedAt = DateTime.utc(2023, 10, 2, 12);
    final base = Conversation.raw(
      id: '123',
      topic: 'Test Topic',
      description: 'Test Description',
      members: const ['1'],
      kIsSecret: false,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    test('equality with identical values', () {
      final other = Conversation.raw(
        id: '123',
        topic: 'Test Topic',
        description: 'Test Description',
        members: const ['1'],
        kIsSecret: false,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
      expect(base, equals(other));
    });

    test('copyWith updates individual fields', () {
      final updated = base.copyWith(topic: 'Updated', members: const ['2']);
      expect(updated.topic, 'Updated');
      expect(updated.members, ['2']);
      expect(updated.id, base.id);
    });

    test('toJson round-trips through fromJson', () {
      final json = base.toJson();
      final parsed = Conversation.fromJson(json);
      expect(parsed.id, base.id);
      expect(parsed.topic, base.topic);
      expect(parsed.description, base.description);
      expect(parsed.members, base.members);
      expect(parsed.kIsSecret, base.kIsSecret);
    });
  });
}

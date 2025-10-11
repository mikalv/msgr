import 'package:msgr_messages/msgr_messages.dart';
import 'package:test/test.dart';

void main() {
  group('MsgrSystemMessage', () {
    const base = MsgrSystemMessage(
      id: 'sys-1',
      text: 'Velkommen!',
      level: MsgrSystemMessageLevel.info,
    );

    test('supports value equality', () {
      const copy = MsgrSystemMessage(
        id: 'sys-1',
        text: 'Velkommen!',
        level: MsgrSystemMessageLevel.info,
      );

      expect(base, equals(copy));
    });

    test('copyWith overrides provided fields', () {
      final updated = base.copyWith(
        level: MsgrSystemMessageLevel.warning,
        theme: const MsgrMessageTheme(
          id: 'alert',
          name: 'Alert',
          primaryColor: '#EF4444',
          backgroundColor: '#FEF2F2',
        ),
      );

      expect(updated.level, equals(MsgrSystemMessageLevel.warning));
      expect(updated.text, equals(base.text));
      expect(updated.theme.id, equals('alert'));
    });

    test('toMap serialises expected structure', () {
      final map = base.toMap();

      expect(map['type'], equals('system'));
      expect(map['level'], equals('info'));
      expect(map['theme'], isA<Map<String, dynamic>>());
    });

    test('fromMap deserialises correctly', () {
      final parsed = MsgrSystemMessage.fromMap({
        'type': 'system',
        'id': 'sys-1',
        'text': 'Velkommen!',
        'level': 'error',
        'sentAt': '2024-01-01T10:00:00.000Z',
        'insertedAt': '2024-01-01T10:00:01.000Z',
        'theme': {
          'id': 'system-dark',
          'name': 'System Dark',
          'primaryColor': '#111827',
          'backgroundColor': '#1F2937',
          'isDark': true,
        },
      });

      expect(parsed.id, equals('sys-1'));
      expect(parsed.level, equals(MsgrSystemMessageLevel.error));
      expect(parsed.sentAt, isNotNull);
      expect(parsed.theme.name, equals('System Dark'));
    });
  });
}

import 'package:msgr_messages/msgr_messages.dart';
import 'package:test/test.dart';

void main() {
  group('MsgrTextMessage', () {
    const base = MsgrTextMessage(
      id: '1',
      body: 'Hello',
      profileId: 'profile-1',
      profileName: 'Alice',
      profileMode: 'private',
      status: 'sent',
    );

    test('supports value equality', () {
      const copy = MsgrTextMessage(
        id: '1',
        body: 'Hello',
        profileId: 'profile-1',
        profileName: 'Alice',
        profileMode: 'private',
        status: 'sent',
      );

      expect(base, equals(copy));
    });

    test('copyWith overrides provided fields', () {
      final updated = base.copyWith(
        body: 'Updated',
        status: 'delivered',
        theme: const MsgrMessageTheme(
          id: 'dark',
          name: 'Dark',
          primaryColor: '#000000',
          backgroundColor: '#111111',
          isDark: true,
        ),
      );

      expect(updated.body, equals('Updated'));
      expect(updated.status, equals('delivered'));
      expect(updated.profileId, equals(base.profileId));
      expect(updated.theme.id, equals('dark'));
    });

    test('toMap serialises expected structure', () {
      final map = base.toMap();

      expect(map['type'], equals('text'));
      expect(map['body'], equals('Hello'));
      expect(map['profileId'], equals('profile-1'));
      expect(map['status'], equals('sent'));
      expect(map['theme'], isA<Map<String, dynamic>>());
    });

    test('fromMap deserialises correctly', () {
      final parsed = MsgrTextMessage.fromMap({
        'type': 'text',
        'id': '1',
        'body': 'Hello',
        'profileId': 'profile-1',
        'profileName': 'Alice',
        'profileMode': 'private',
        'status': 'sent',
        'sentAt': '2024-01-01T10:00:00.000Z',
        'insertedAt': '2024-01-01T10:00:01.000Z',
        'theme': {
          'id': 'sunset',
          'name': 'Sunset',
          'primaryColor': '#F97316',
          'backgroundColor': '#1F2937',
          'isDark': true,
        },
      });

      expect(parsed.id, equals('1'));
      expect(parsed.profileName, equals('Alice'));
      expect(parsed.sentAt, isNotNull);
      expect(parsed.theme.id, equals('sunset'));
    });
  });
}

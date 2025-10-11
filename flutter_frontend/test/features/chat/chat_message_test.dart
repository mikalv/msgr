import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/features/chat/models/chat_message.dart';
import 'package:msgr_messages/msgr_messages.dart';

void main() {
  group('ChatMessage', () {
    final message = ChatMessage.text(
      id: '1',
      body: 'Hei',
      profileId: 'profile',
      profileName: 'Ola',
      profileMode: 'private',
      status: 'sent',
      sentAt: DateTime(2024, 1, 1, 10),
      insertedAt: DateTime(2024, 1, 1, 10, 0, 1),
    );

    test('copyWith returns ChatMessage', () {
      final copy = message.copyWith(
        body: 'Hallo',
        theme: const MsgrMessageTheme(
          id: 'midnight',
          name: 'Midnight',
          primaryColor: '#0F172A',
          backgroundColor: '#1E293B',
          isDark: true,
        ),
      );

      expect(copy, isA<ChatMessage>());
      expect(copy.body, equals('Hallo'));
      expect(copy.profileId, equals(message.profileId));
      expect(copy.theme.id, equals('midnight'));
    });

    test('toJson keeps backwards compatible keys', () {
      final json = message.toJson();

      expect(json['type'], equals('text'));
      expect(json['body'], equals('Hei'));
      expect(json['sentAt'], equals('2024-01-01T10:00:00.000'));
      expect(json['theme'], isA<Map<String, dynamic>>());
      expect(json.containsKey('payload'), isFalse);
    });

    test('fromJson parses profile structure', () {
      final parsed = ChatMessage.fromJson({
        'id': '1',
        'body': 'Hei',
        'status': 'sent',
        'sent_at': '2024-01-01T10:00:00.000Z',
        'inserted_at': '2024-01-01T10:00:01.000Z',
        'profile': {
          'id': 'profile',
          'name': 'Ola',
          'mode': 'public',
        },
        'theme': {
          'id': 'aurora',
          'name': 'Aurora',
          'primaryColor': '#38BDF8',
          'backgroundColor': '#0F172A',
          'isDark': true,
        }
      });

      expect(parsed.profileName, equals('Ola'));
      expect(parsed.profileMode, equals('public'));
      expect(parsed.sentAt, isNotNull);
      expect(parsed.theme.name, equals('Aurora'));
    });

    test('applyTheme uses palette to resolve entry', () {
      final palette = MsgrThemePalette.standard();

      final themed = message.applyTheme(palette, themeId: 'sunrise');

      expect(themed.theme.id, equals('sunrise'));
      expect(themed, isA<ChatMessage>());
    });
  });
}

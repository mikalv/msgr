import 'package:msgr_messages/msgr_messages.dart';
import 'package:test/test.dart';

void main() {
  group('MsgrMarkdownMessage', () {
    const base = MsgrMarkdownMessage(
      id: 'markdown-1',
      markdown: '# Hello',
      profileId: 'profile-1',
      profileName: 'Alice',
      profileMode: 'public',
      status: 'sent',
    );

    test('copyWith overrides trusted flag', () {
      final copy = base.copyWith(
        isTrusted: true,
        theme: const MsgrMessageTheme(
          id: 'emerald',
          name: 'Emerald',
          primaryColor: '#10B981',
          backgroundColor: '#064E3B',
        ),
      );

      expect(copy.isTrusted, isTrue);
      expect(copy.markdown, equals('# Hello'));
      expect(copy.theme.id, equals('emerald'));
    });

    test('fromMap supports fallback body key', () {
      final parsed = MsgrMarkdownMessage.fromMap({
        'type': 'markdown',
        'id': 'markdown-1',
        'body': 'Fallback',
        'profileId': 'profile-1',
        'profileName': 'Alice',
        'profileMode': 'public',
        'status': 'delivered',
        'isTrusted': true,
        'theme': {
          'id': 'docs',
          'name': 'Docs',
          'primaryColor': '#1D4ED8',
          'backgroundColor': '#E0F2FE',
          'isDark': false,
        },
      });

      expect(parsed.markdown, equals('Fallback'));
      expect(parsed.isTrusted, isTrue);
      expect(parsed.status, equals('delivered'));
      expect(parsed.theme.name, equals('Docs'));
    });

    test('toMap exposes trusted flag and markdown', () {
      final map = base.copyWith(isTrusted: true).toMap();

      expect(map['type'], equals('markdown'));
      expect(map['markdown'], equals('# Hello'));
      expect(map['isTrusted'], isTrue);
      expect(map['theme'], isA<Map<String, dynamic>>());
    });
  });
}

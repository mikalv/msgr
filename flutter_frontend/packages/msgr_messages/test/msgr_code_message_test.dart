import 'package:msgr_messages/msgr_messages.dart';
import 'package:test/test.dart';

void main() {
  group('MsgrCodeMessage', () {
    const base = MsgrCodeMessage(
      id: 'code-1',
      code: 'print("hello")',
      language: 'dart',
      caption: 'Example snippet',
      profileId: 'profile-1',
      profileName: 'Alice',
      profileMode: 'bot',
    );

    test('copyWith overrides provided fields', () {
      final copy = base.copyWith(
        language: 'python',
        caption: 'Py snippet',
        theme: const MsgrMessageTheme(
          id: 'mono',
          name: 'Monochrome',
          primaryColor: '#FFFFFF',
          backgroundColor: '#000000',
          isDark: true,
        ),
      );

      expect(copy.language, equals('python'));
      expect(copy.caption, equals('Py snippet'));
      expect(copy.code, equals(base.code));
      expect(copy.theme.name, equals('Monochrome'));
    });

    test('fromMap populates defaults', () {
      final parsed = MsgrCodeMessage.fromMap({
        'type': 'code',
        'id': 'code-1',
        'code': 'puts "Hi"',
        'profileId': 'profile-1',
        'profileName': 'Alice',
        'profileMode': 'bot',
      });

      expect(parsed.language, equals('plaintext'));
      expect(parsed.caption, isNull);
      expect(parsed.theme.id, equals('default'));
    });

    test('toMap serialises caption and language', () {
      final map = base.toMap();

      expect(map['type'], equals('code'));
      expect(map['language'], equals('dart'));
      expect(map['caption'], equals('Example snippet'));
      expect(map['theme'], isA<Map<String, dynamic>>());
    });
  });
}

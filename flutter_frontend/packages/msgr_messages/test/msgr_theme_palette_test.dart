import 'package:msgr_messages/msgr_messages.dart';
import 'package:test/test.dart';

void main() {
  group('MsgrThemePalette', () {
    final palette = MsgrThemePalette.standard();

    test('resolve returns fallback when theme is unknown', () {
      final resolved = palette.resolve('missing');

      expect(resolved, equals(MsgrMessageTheme.defaultTheme));
    });

    test('register returns palette with new theme', () {
      const custom = MsgrMessageTheme(
        id: 'custom',
        name: 'Custom',
        primaryColor: '#10B981',
        backgroundColor: '#ECFDF5',
      );

      final extended = palette.register(custom);

      expect(extended.resolve('custom'), equals(custom));
    });

    test('apply replaces the message theme', () {
      const message = MsgrTextMessage(
        id: '1',
        body: 'Hei',
        profileId: 'p1',
        profileName: 'Ola',
        profileMode: 'private',
        status: 'sent',
      );

      final themed = palette.apply(message, themeId: 'aurora');

      expect(themed.theme.id, equals('aurora'));
      expect(themed, isA<MsgrTextMessage>());
    });
  });
}

import 'package:msgr_messages/msgr_messages.dart';
import 'package:test/test.dart';

void main() {
  group('MsgrMessageTheme', () {
    test('copyWith overrides provided fields', () {
      const theme = MsgrMessageTheme(
        id: 'default',
        name: 'Default',
        primaryColor: '#2563EB',
        backgroundColor: '#F8FAFC',
      );

      final copy = theme.copyWith(name: 'Night', isDark: true);

      expect(copy.name, equals('Night'));
      expect(copy.isDark, isTrue);
      expect(copy.primaryColor, equals('#2563EB'));
    });

    test('toMap and fromMap round trip', () {
      const theme = MsgrMessageTheme(
        id: 'retro',
        name: 'Retro',
        primaryColor: '#F97316',
        backgroundColor: '#FEF3C7',
        isDark: false,
      );

      final map = theme.toMap();
      final parsed = MsgrMessageTheme.fromMap(map);

      expect(parsed, equals(theme));
    });

    test('fromMap applies defaults when missing fields', () {
      final parsed = MsgrMessageTheme.fromMap({});

      expect(parsed.id, equals('default'));
      expect(parsed.name, equals('Default'));
      expect(parsed.isDark, isFalse);
    });
  });
}

import 'package:msgr_messages/msgr_messages.dart';
import 'package:test/test.dart';

void main() {
  group('MsgrBubbleStyle', () {
    const style = MsgrBubbleStyle(
      backgroundColor: '#FFFFFF',
      textColor: '#111111',
      borderColor: '#DDDDDD',
      borderWidth: 2,
      cornerRadius: 12,
      linkColor: '#2563EB',
    );

    test('supports copyWith overrides', () {
      final copy = style.copyWith(textColor: '#000000', borderWidth: 1);

      expect(copy.textColor, equals('#000000'));
      expect(copy.borderWidth, equals(1));
      expect(copy.backgroundColor, equals('#FFFFFF'));
    });

    test('round trips through map', () {
      final map = style.toMap();
      final parsed = MsgrBubbleStyle.fromMap(map);

      expect(parsed, equals(style));
    });

    test('fromMap applies sensible defaults', () {
      final parsed = MsgrBubbleStyle.fromMap({});

      expect(parsed.backgroundColor, equals('#FFFFFF'));
      expect(parsed.cornerRadius, equals(18));
    });
  });

  group('MsgrMessageTheme', () {
    const theme = MsgrMessageTheme(
      id: 'retro',
      name: 'Retro',
      primaryColor: '#F97316',
      backgroundColor: '#FEF3C7',
      incomingBubble: MsgrBubbleStyle(
        backgroundColor: '#FEF3C7',
        textColor: '#92400E',
      ),
      outgoingBubble: MsgrBubbleStyle(
        backgroundColor: '#F97316',
        textColor: '#FFF7ED',
      ),
      systemBubble: MsgrBubbleStyle(
        backgroundColor: '#FFEDD5',
        textColor: '#78350F',
      ),
      isDark: false,
      fontFamily: 'Inter',
      timestampTextColor: '#F59E0B',
      reactionBackgroundColor: '#FED7AA',
      avatarBackgroundColor: '#FFEDD5',
      avatarBorderColor: '#F97316',
      bubbleSpacing: 12,
      showAvatars: false,
    );

    test('copyWith overrides provided fields', () {
      final copy = theme.copyWith(name: 'Night', isDark: true);

      expect(copy.name, equals('Night'));
      expect(copy.isDark, isTrue);
      expect(copy.primaryColor, equals('#F97316'));
      expect(copy.incomingBubble, equals(theme.incomingBubble));
    });

    test('toMap and fromMap round trip', () {
      final map = theme.toMap();
      final parsed = MsgrMessageTheme.fromMap(map);

      expect(parsed, equals(theme));
    });

    test('fromMap applies defaults when missing fields', () {
      final parsed = MsgrMessageTheme.fromMap({});

      expect(parsed.id, equals('default'));
      expect(parsed.name, equals('Default'));
      expect(parsed.incomingBubble, equals(MsgrBubbleStyle.defaultIncoming));
      expect(parsed.outgoingBubble, equals(MsgrBubbleStyle.defaultOutgoing));
    });
  });
}

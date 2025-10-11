import 'package:msgr_messages/msgr_messages.dart';
import 'package:test/test.dart';

void main() {
  group('MsgrVideoMessage', () {
    const base = MsgrVideoMessage(
      id: 'vid-1',
      url: 'https://example.com/video.mp4',
      profileId: 'profile-1',
      profileName: 'Alice',
      profileMode: 'bot',
    );

    test('copyWith overrides playback fields', () {
      final copy = base.copyWith(
        caption: 'Demo clip',
        duration: 42.5,
        autoplay: true,
        theme: const MsgrMessageTheme(
          id: 'cinema',
          name: 'Cinema',
          primaryColor: '#BE123C',
          backgroundColor: '#111827',
          isDark: true,
        ),
      );

      expect(copy.caption, equals('Demo clip'));
      expect(copy.duration, equals(42.5));
      expect(copy.autoplay, isTrue);
      expect(copy.theme.name, equals('Cinema'));
    });

    test('fromMap parses numeric duration', () {
      final parsed = MsgrVideoMessage.fromMap({
        'type': 'video',
        'id': 'vid-1',
        'url': 'https://example.com/video.mp4',
        'duration': 60,
        'profileId': 'profile-1',
        'profileName': 'Alice',
        'profileMode': 'bot',
      });

      expect(parsed.duration, equals(60));
      expect(parsed.autoplay, isFalse);
    });

    test('toMap serialises autoplay and caption', () {
      final map = base.copyWith(caption: 'Clip', autoplay: true).toMap();

      expect(map['type'], equals('video'));
      expect(map['caption'], equals('Clip'));
      expect(map['autoplay'], isTrue);
      expect(map['theme'], isA<Map<String, dynamic>>());
    });
  });
}

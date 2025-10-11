import 'package:msgr_messages/msgr_messages.dart';
import 'package:test/test.dart';

void main() {
  group('MsgrImageMessage', () {
    const base = MsgrImageMessage(
      id: 'img-1',
      url: 'https://example.com/image.png',
      profileId: 'profile-1',
      profileName: 'Alice',
      profileMode: 'public',
    );

    test('copyWith overrides provided fields', () {
      final copy = base.copyWith(
        description: 'Sunset image',
        width: 1024,
        height: 768,
        theme: const MsgrMessageTheme(
          id: 'sunset',
          name: 'Sunset',
          primaryColor: '#F97316',
          backgroundColor: '#1F2937',
          isDark: true,
        ),
      );

      expect(copy.description, equals('Sunset image'));
      expect(copy.width, equals(1024));
      expect(copy.height, equals(768));
      expect(copy.theme.id, equals('sunset'));
    });

    test('fromMap parses numeric dimensions', () {
      final parsed = MsgrImageMessage.fromMap({
        'type': 'image',
        'id': 'img-1',
        'url': 'https://example.com/image.png',
        'width': 640.0,
        'height': 480,
        'profileId': 'profile-1',
        'profileName': 'Alice',
        'profileMode': 'public',
        'theme': {
          'id': 'photo',
          'name': 'Photo',
          'primaryColor': '#3B82F6',
          'backgroundColor': '#EFF6FF',
          'isDark': false,
        },
      });

      expect(parsed.width, equals(640));
      expect(parsed.height, equals(480));
      expect(parsed.theme.name, equals('Photo'));
    });

    test('toMap serialises media fields', () {
      final map = base.copyWith(thumbnailUrl: 'thumb.png').toMap();

      expect(map['type'], equals('image'));
      expect(map['thumbnailUrl'], equals('thumb.png'));
      expect(map['theme'], isA<Map<String, dynamic>>());
    });
  });
}

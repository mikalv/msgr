import 'package:msgr_messages/msgr_messages.dart';
import 'package:test/test.dart';

void main() {
  group('msgrMessageFromMap', () {
    test('creates MsgrTextMessage when type is text', () {
      final message = msgrMessageFromMap({
        'type': 'text',
        'id': '1',
        'body': 'Hello',
        'profileId': 'p1',
        'profileName': 'Alice',
        'profileMode': 'private',
      });

      expect(message, isA<MsgrTextMessage>());
    });

    test('creates MsgrMarkdownMessage when type is markdown', () {
      final message = msgrMessageFromMap({
        'type': 'markdown',
        'id': '2',
        'markdown': '# Hello',
        'profileId': 'p1',
        'profileName': 'Alice',
        'profileMode': 'private',
      });

      expect(message, isA<MsgrMarkdownMessage>());
    });

    test('creates MsgrCodeMessage when type is code', () {
      final message = msgrMessageFromMap({
        'type': 'code',
        'id': '3',
        'code': 'print("Hi")',
        'profileId': 'p1',
        'profileName': 'Alice',
        'profileMode': 'private',
      });

      expect(message, isA<MsgrCodeMessage>());
    });

    test('creates MsgrSystemMessage when type is system', () {
      final message = msgrMessageFromMap({
        'type': 'system',
        'id': 'sys1',
        'text': 'Velkommen!',
      });

      expect(message, isA<MsgrSystemMessage>());
    });

    test('creates MsgrImageMessage when type is image', () {
      final message = msgrMessageFromMap({
        'type': 'image',
        'id': 'img-1',
        'url': 'https://example.com/image.png',
        'profileId': 'p1',
        'profileName': 'Alice',
        'profileMode': 'private',
      });

      expect(message, isA<MsgrImageMessage>());
    });

    test('creates MsgrVideoMessage when type is video', () {
      final message = msgrMessageFromMap({
        'type': 'video',
        'id': 'vid-1',
        'url': 'https://example.com/video.mp4',
        'profileId': 'p1',
        'profileName': 'Alice',
        'profileMode': 'private',
      });

      expect(message, isA<MsgrVideoMessage>());
    });

    test('creates MsgrAudioMessage when type is audio', () {
      final message = msgrMessageFromMap({
        'type': 'audio',
        'id': 'aud-1',
        'url': 'https://example.com/audio.mp3',
        'profileId': 'p1',
        'profileName': 'Alice',
        'profileMode': 'private',
      });

      expect(message, isA<MsgrAudioMessage>());
    });

    test('creates MsgrLocationMessage when type is location', () {
      final message = msgrMessageFromMap({
        'type': 'location',
        'id': 'loc-1',
        'latitude': 10.0,
        'longitude': 59.9,
        'profileId': 'p1',
        'profileName': 'Alice',
        'profileMode': 'private',
      });

      expect(message, isA<MsgrLocationMessage>());
    });

    test('throws when type is missing', () {
      expect(() => msgrMessageFromMap({'id': '1'}), throwsFormatException);
    });

    test('throws when type is unknown', () {
      expect(
        () => msgrMessageFromMap({'id': '1', 'type': 'unsupported'}),
        throwsFormatException,
      );
    });
  });
}

import 'package:msgr_messages/msgr_messages.dart';
import 'package:test/test.dart';

void main() {
  group('MsgrAudioMessage', () {
    const message = MsgrAudioMessage(
      id: 'audio-1',
      url: 'https://cdn.msgr.dev/audio.mp3',
      caption: 'Hør her',
      duration: 12.5,
      waveform: [0.1, 0.5, 0.9],
      mimeType: 'audio/mpeg',
      profileId: 'profile-1',
      profileName: 'Kari',
      profileMode: 'private',
      status: 'sent',
    );

    test('supports value equality', () {
      const copy = MsgrAudioMessage(
        id: 'audio-1',
        url: 'https://cdn.msgr.dev/audio.mp3',
        caption: 'Hør her',
        duration: 12.5,
        waveform: [0.1, 0.5, 0.9],
        mimeType: 'audio/mpeg',
        profileId: 'profile-1',
        profileName: 'Kari',
        profileMode: 'private',
        status: 'sent',
      );

      expect(message, equals(copy));
    });

    test('copyWith overrides provided fields', () {
      final updated = message.copyWith(
        caption: 'Ny caption',
        mimeType: 'audio/ogg',
        waveform: const [0.2, 0.3],
        theme: const MsgrMessageTheme(
          id: 'aurora',
          name: 'Aurora',
          primaryColor: '#38BDF8',
          backgroundColor: '#0F172A',
        ),
      );

      expect(updated.caption, equals('Ny caption'));
      expect(updated.mimeType, equals('audio/ogg'));
      expect(updated.waveform, equals(const [0.2, 0.3]));
      expect(updated.theme.id, equals('aurora'));
    });

    test('toMap serialises expected structure', () {
      final map = message.toMap();

      expect(map['type'], equals('audio'));
      expect(map['url'], equals('https://cdn.msgr.dev/audio.mp3'));
      expect(map['waveform'], equals(const [0.1, 0.5, 0.9]));
      expect(map['mimeType'], equals('audio/mpeg'));
    });

    test('fromMap deserialises correctly', () {
      final parsed = MsgrAudioMessage.fromMap({
        'type': 'audio',
        'id': 'audio-1',
        'url': 'https://cdn.msgr.dev/audio.mp3',
        'caption': 'Hør her',
        'duration': 10.0,
        'waveform': [0.1, 0.2],
        'mimeType': 'audio/mpeg',
        'profileId': 'profile-1',
        'profileName': 'Kari',
        'profileMode': 'private',
        'status': 'sent',
        'sentAt': '2024-01-01T10:00:00.000Z',
        'insertedAt': '2024-01-01T10:00:01.000Z',
      });

      expect(parsed.url, equals('https://cdn.msgr.dev/audio.mp3'));
      expect(parsed.duration, equals(10.0));
      expect(parsed.waveform, equals([0.1, 0.2]));
    });

    test('themed applies palette entry', () {
      const theme = MsgrMessageTheme(
        id: 'midnight',
        name: 'Midnight',
        primaryColor: '#0F172A',
        backgroundColor: '#1E293B',
      );

      final themed = message.themed(theme);

      expect(themed.theme.id, equals('midnight'));
    });
  });
}

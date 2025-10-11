import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/features/chat/models/chat_message.dart';
import 'package:messngr/features/chat/widgets/chat_bubble.dart';
import 'package:msgr_messages/msgr_messages.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatBubble', () {
    testWidgets('renders image previews with caption', (tester) async {
      final message = ChatMessage.fromMsgrMessage(
        MsgrImageMessage(
          id: '1',
          url: 'https://example.com/image.jpg',
          description: 'Hei verden',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          width: 800,
          height: 600,
          profileId: 'p1',
          profileName: 'Ola',
          profileMode: 'private',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(message: message, isMine: false),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.text('Hei verden'), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });

    testWidgets('renders voice notes with waveform and duration', (tester) async {
      final audio = MsgrAudioMessage(
        id: 'voice1',
        url: 'https://example.com/voice.ogg',
        duration: 2.5,
        waveform: const [0, 50, 100],
        profileId: 'p1',
        profileName: 'Ola',
        profileMode: 'private',
        kind: MsgrMessageKind.voice,
      );
      final message = ChatMessage.fromMsgrMessage(audio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(message: message, isMine: true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.text('00:02'), findsOneWidget);
    });
  });
}

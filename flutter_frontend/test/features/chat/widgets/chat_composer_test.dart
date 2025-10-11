import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/features/chat/media/chat_media_attachment.dart';
import 'package:messngr/features/chat/media/chat_media_controller.dart';
import 'package:messngr/features/chat/models/composer_submission.dart';
import 'package:messngr/features/chat/widgets/chat_composer.dart';

void main() {
  testWidgets('displays attachment previews and sends submission', (tester) async {
    final controller = ChatMediaController();
    final attachments = [
      ChatMediaAttachment(
        id: 'image-1',
        type: ChatMediaType.image,
        fileName: 'sunset.png',
        mimeType: 'image/png',
        bytes: Uint8List.fromList(List<int>.filled(8, 128)),
        width: 1280,
        height: 720,
      ),
      ChatMediaAttachment(
        id: 'audio-1',
        type: ChatMediaType.audio,
        fileName: 'voice.mp3',
        mimeType: 'audio/mpeg',
        bytes: Uint8List.fromList(List<int>.filled(12, 64)),
        waveform: const [0.1, 0.3, 0.6, 0.2],
      ),
    ];
    controller.addAttachments(attachments);

    ComposerSubmission? submission;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposer(
            onSend: (value) => submission = value,
            isSending: false,
            mediaController: controller,
          ),
        ),
      ),
    );

    expect(find.text('sunset.png'), findsOneWidget);
    expect(find.text('voice.mp3'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Bildetekst');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(submission, isNotNull);
    expect(submission!.text, equals('Bildetekst'));
    expect(submission!.attachments, hasLength(2));
    expect(controller.attachments, isEmpty);
  });
}

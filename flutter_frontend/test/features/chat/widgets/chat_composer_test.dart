import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/features/chat/widgets/chat_composer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('send button enabled when text is entered', (tester) async {
    ChatComposerResult? submitted;
    final controller = ChatComposerController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposer(
            controller: controller,
            onSubmit: (value) => submitted = value,
            isSending: false,
          ),
        ),
      ),
    );

    expect(submitted, isNull);
    await tester.enterText(find.byType(TextField), 'Hei der');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.text, 'Hei der');
    expect(submitted!.attachments, isEmpty);
  });

  testWidgets('emoji picker inserts emoji at caret', (tester) async {
    final controller = ChatComposerController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposer(
            controller: controller,
            onSubmit: (_) {},
            isSending: false,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('😀'));
    await tester.pumpAndSettle();

    expect(controller.value.text.contains('😀'), isTrue);
  });

  testWidgets('slash command palette can be navigated', (tester) async {
    ChatComposerResult? submitted;
    final controller = ChatComposerController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposer(
            controller: controller,
            onSubmit: (value) => submitted = value,
            isSending: false,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '/g');
    await tester.pumpAndSettle();

    expect(find.text('/giphy'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.command, isNotNull);
    expect(submitted!.command!.name, '/giphy');
  });

  testWidgets('file attachments are displayed and removable', (tester) async {
    final controller = ChatComposerController();
    final original = FilePicker.platform;
    addTearDown(() => FilePickerPlatform.instance = original);
    FilePickerPlatform.instance = _FakeFilePicker([
      PlatformFile(
        name: 'fil.txt',
        size: 4,
        bytes: Uint8List.fromList([1, 2, 3, 4]),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposer(
            controller: controller,
            onSubmit: (_) {},
            isSending: false,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.attach_file));
    await tester.pumpAndSettle();

    expect(find.textContaining('fil.txt'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.cancel));
    await tester.pumpAndSettle();

    expect(find.textContaining('fil.txt'), findsNothing);
  });

  testWidgets('voice recorder updates controller with note', (tester) async {
    final controller = ChatComposerController();
    final recorder = _FakeVoiceRecorder();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposer(
            controller: controller,
            onSubmit: (_) {},
            isSending: false,
            voiceRecorder: recorder,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pumpAndSettle();

    expect(recorder.isRecording, isTrue);

    await tester.tap(find.byIcon(Icons.stop_circle_rounded));
    await tester.pumpAndSettle();

    expect(controller.value.voiceNote, isNotNull);
  });
}

class _FakeFilePicker extends FilePickerPlatform {
  _FakeFilePicker(this.files);

  final List<PlatformFile> files;

  @override
  Future<FilePickerResult?> pickFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowCompression = true,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    String? dialogTitle,
    String? initialDirectory,
    String? helpText,
    bool? allowFolderCreation,
  }) async {
    return FilePickerResult(files);
  }

  @override
  Future<bool> clearTemporaryFiles() async => true;

  @override
  Future<String?> getDirectoryPath({String? dialogTitle}) async => null;

  @override
  Future<FilePickerResult?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool? allowFolderCreation,
    bool lockParentWindow = false,
  }) async => null;
}

class _FakeVoiceRecorder implements ChatVoiceRecorder {
  final StreamController<ChatVoiceState> _controller =
      StreamController<ChatVoiceState>.broadcast();
  bool _recording = false;

  @override
  bool get isRecording => _recording;

  @override
  Stream<ChatVoiceState> get stateStream => _controller.stream;

  @override
  Future<void> start() async {
    _recording = true;
    _controller.add(const ChatVoiceState(isRecording: true));
  }

  @override
  Future<ComposerVoiceNote> stop() async {
    _recording = false;
    _controller.add(const ChatVoiceState(isRecording: false));
    return ComposerVoiceNote(
      duration: const Duration(seconds: 2),
      bytes: Uint8List.fromList([1, 2, 3]),
    );
  }
}

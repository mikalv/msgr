part of 'package:messngr/features/chat/widgets/chat_composer.dart';

abstract class ChatVoiceRecorder {
  bool get isRecording;
  Stream<ChatVoiceState> get stateStream;
  Future<void> start();
  Future<ComposerVoiceNote> stop();
}

class ChatVoiceState {
  const ChatVoiceState({required this.isRecording});

  final bool isRecording;
}

class SimulatedChatVoiceRecorder implements ChatVoiceRecorder {
  final StreamController<ChatVoiceState> _controller =
      StreamController<ChatVoiceState>.broadcast();
  final Random _random = Random();
  Stopwatch? _stopwatch;

  @override
  bool get isRecording => _stopwatch?.isRunning == true;

  @override
  Stream<ChatVoiceState> get stateStream => _controller.stream;

  @override
  Future<void> start() async {
    _stopwatch ??= Stopwatch();
    _stopwatch!.start();
    _controller.add(const ChatVoiceState(isRecording: true));
  }

  @override
  Future<ComposerVoiceNote> stop() async {
    _stopwatch?.stop();
    final duration = _stopwatch?.elapsed ?? Duration.zero;
    _stopwatch?.reset();
    _controller.add(const ChatVoiceState(isRecording: false));
    final bytes = Uint8List.fromList(
      List<int>.generate(1200, (_) => _random.nextInt(255)),
    );
    return ComposerVoiceNote(duration: duration, bytes: bytes);
  }
}

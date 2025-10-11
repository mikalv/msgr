import 'dart:async';
import 'dart:isolate';

class Worker {
  late SendPort _sendPort;
  late Isolate _isolate;

  Completer<void> _isolateReady = Completer<void>();

  Worker() {
    init();
  }

  Future<void> init() async {
    final receivePort = ReceivePort();

    receivePort.listen(_handleMessage);
    _isolate = await Isolate.spawn(_isolateEntry, receivePort.sendPort);
  }

  Future<void> get isolateReady => _isolateReady.future;

  static void _isolateEntry(dynamic message) {
    SendPort sendPort;
    final receivePort = ReceivePort();
    receivePort.listen(
      (message) {},
    );
    if (message is SendPort) {
      sendPort = message;
      sendPort.send(receivePort.sendPort);
    }
  }

  void _handleMessage(dynamic message) {
    if (message is SendPort) {
      _sendPort = message;
      _isolateReady.complete();
    } else {
      print('Received: $message');
    }
  }
}

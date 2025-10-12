import 'package:flutter/foundation.dart';

class ThreadViewState {
  const ThreadViewState(
      {this.threadId, this.rootMessageId, this.showPinned = false});

  final String? threadId;
  final String? rootMessageId;
  final bool showPinned;
}

class ThreadViewNotifier extends ChangeNotifier {
  ThreadViewState _state = const ThreadViewState();

  ThreadViewState get state => _state;

  void openThread(String threadId, {required String rootMessageId}) {
    _state = ThreadViewState(
        threadId: threadId,
        rootMessageId: rootMessageId,
        showPinned: _state.showPinned);
    notifyListeners();
  }

  void closeThread() {
    if (_state.threadId == null && !_state.showPinned) return;
    _state = ThreadViewState(showPinned: _state.showPinned);
    notifyListeners();
  }

  void setPinnedView(bool value) {
    if (_state.showPinned == value) return;
    _state = ThreadViewState(
      threadId: value ? null : _state.threadId,
      rootMessageId: value ? null : _state.rootMessageId,
      showPinned: value,
    );
    notifyListeners();
  }
}

import 'dart:ui';

class UiActions {}

class OnWindowBlur extends UiActions {
  @override
  String toString() {
    return 'OnWindowBlur{}';
  }
}

class OnWindowFocus extends UiActions {
  @override
  String toString() {
    return 'OnWindowFocus{}';
  }
}

class OnWindowMinimize extends UiActions {
  @override
  String toString() {
    return 'OnWindowMinimize{}';
  }
}

class OnWindowRestore extends UiActions {
  @override
  String toString() {
    return 'OnWindowRestore{}';
  }
}

class OnWindowResize extends UiActions {
  final Size windowSize;

  OnWindowResize({required this.windowSize});

  @override
  String toString() {
    return 'OnWindowResize{windowSize: $windowSize}';
  }
}

class OnWindowMove extends UiActions {
  final Offset windowPosition;

  OnWindowMove({required this.windowPosition});

  @override
  String toString() {
    return 'OnWindowMove{windowPosition: $windowPosition}';
  }
}

class ChangeRegisterTabAction {
  final int currentIndex;

  ChangeRegisterTabAction({required this.currentIndex});
}

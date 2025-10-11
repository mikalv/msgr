import 'dart:ui';

/// Represents the UI state of the application.
///
/// This class is used to manage and store the state of the user interface,
/// including any relevant information that needs to be preserved across
/// different parts of the application.
class UiState {
  final bool isLoading;

  final Offset windowPosition;
  final Size windowSize;
  final bool isMinimized;
  final bool hasFocus;

  UiState(
      {required this.windowPosition,
      required this.windowSize,
      this.isLoading = false,
      this.isMinimized = false,
      this.hasFocus = true});

  UiState copyWith({required bool isLoading}) {
    return UiState(
      windowPosition: windowPosition,
      windowSize: windowSize,
      isLoading: isLoading ?? isLoading,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UiState &&
          runtimeType == other.runtimeType &&
          isLoading == other.isLoading &&
          windowPosition == other.windowPosition &&
          windowSize == other.windowSize;

  @override
  int get hashCode =>
      isLoading.hashCode ^ windowPosition.hashCode ^ windowSize.hashCode;

  @override
  String toString() {
    return 'UiState{isLoading: $isLoading, windowPosition: $windowPosition, windowSize: $windowSize}';
  }
}

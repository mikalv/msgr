import 'dart:async';

extension ListHelper<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;

  T? get lastOrNull => isEmpty ? null : last;
}

/// List extension
extension IterableExtension<T> on Iterable<T> {
  /// Insert any item<T> inBetween the list items
  List<T> insertBetween(T item) => expand((e) sync* {
        yield item;
        yield e;
      }).skip(1).toList(growable: false);
}

/// Useful extension functions for [Iterable]
extension IterableX<T> on Iterable<T?> {
  /// Removes all the null values
  /// and converts `Iterable<T?>` into `Iterable<T>`
  Iterable<T> get withNullifyer => whereType();
}

/// Useful extension functions for [Map]
extension MapX<K, V> on Map<K?, V?> {
  /// Returns a new map with null keys or values removed
  Map<K, V> get nullProtected {
    final nullProtected = {...this}
      ..removeWhere((key, value) => key == null || value == null);
    return nullProtected.cast();
  }
}

/// Extension on [StreamController] to safely add events and errors.
extension StreamControllerX<T> on StreamController<T> {
  /// Safely adds the event to the controller,
  /// Returns early if the controller is closed.
  void safeAdd(T event) {
    if (isClosed) return;
    add(event);
  }

  /// Safely adds the error to the controller,
  /// Returns early if the controller is closed.
  void safeAddError(Object error, [StackTrace? stackTrace]) {
    if (isClosed) return;
    addError(error, stackTrace);
  }
}

import 'package:libmsgr/src/typedefs.dart';

abstract class ASecureStorage {
  Future<bool> containsKey(key);
  Future<String?> readValue(key);
  Future<Map<String, String>> readAll();
  Future<String> writeValue(key, value);
  Future<void> deleteAll();
  Future<void> deleteKey(key);
}

abstract class ASharedPreferences {
  Future<void> clear({Set<String>? allowList});
  Future<bool> containsKey(String key);
  Future<Map<String, Object?>> getAll({Set<String>? allowList});
  Future<bool?> getBool(String key);
  Future<double?> getDouble(String key);
  Future<int?> getInt(String key);
  Future<Set<String>> getKeys({Set<String>? allowList});
  Future<String?> getString(String key);
  Future<List<String>?> getStringList(String key);
  Future<void> remove(String key);
  Future<void> setBool(String key, bool value);
  Future<void> setDouble(String key, double value);
  Future<void> setInt(String key, int value);
  Future<void> setString(String key, String value);
  Future<void> setStringList(String key, List<String> value);
}

abstract class ADeviceInfo {
  Future<Map<dynamic, dynamic>> extractInformation();
}

abstract class Listenable {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const Listenable();

  /// Register a closure to be called when the object notifies its listeners.
  void addListener(VoidCallback listener);

  /// Remove a previously registered closure from the list of closures that the
  /// object notifies.
  void removeListener(VoidCallback listener);
}

/// An interface for subclasses of [Listenable] that expose a [value].
///
/// This interface is implemented by [ValueNotifier<T>] and [Animation<T>], and
/// allows other APIs to accept either of those implementations interchangeably.
///
/// See also:
///
///  * [ValueListenableBuilder], a widget that uses a builder callback to
///    rebuild whenever a [ValueListenable] object triggers its notifications,
///    providing the builder with the value of the object.
abstract class ValueListenable<T> extends Listenable {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const ValueListenable();

  /// The current value of the object. When the value changes, the callbacks
  /// registered with [addListener] will be invoked.
  T get value;
}

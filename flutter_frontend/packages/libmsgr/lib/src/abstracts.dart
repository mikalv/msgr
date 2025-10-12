import 'package:libmsgr/src/typedefs.dart';
import 'package:libmsgr_core/libmsgr_core.dart' as core;

typedef ASecureStorage = core.SecureStorage;
typedef ASharedPreferences = core.KeyValueStore;

abstract class ADeviceInfo extends core.DeviceInfoProvider {
  /// Legacy API preserved for existing call sites.
  Future<Map<dynamic, dynamic>> extractInformation();

  @override
  Future<Map<String, dynamic>> deviceInfo() async {
    final raw = await extractInformation();
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  @override
  Future<Map<String, dynamic>> appInfo();
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

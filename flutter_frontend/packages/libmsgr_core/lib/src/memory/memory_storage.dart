import '../contracts/storage.dart';

/// In-memory [SecureStorage] suitable for tests and CLI tooling.
class MemorySecureStorage implements SecureStorage {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<bool> containsKey(String key) async => _values.containsKey(key);

  @override
  Future<void> deleteAll() async => _values.clear();

  @override
  Future<void> deleteKey(String key) async => _values.remove(key);

  @override
  Future<Map<String, String>> readAll() async =>
      Map<String, String>.from(_values);

  @override
  Future<String?> readValue(String key) async => _values[key];

  @override
  Future<void> writeValue(String key, String value) async {
    _values[key] = value;
  }
}

/// In-memory [KeyValueStore] implementation.
class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, Object?> _store = <String, Object?>{};

  @override
  Future<void> clear({Set<String>? allowList}) async {
    if (allowList == null) {
      _store.clear();
      return;
    }
    _store.removeWhere((key, _) => !allowList.contains(key));
  }

  @override
  Future<bool> containsKey(String key) async => _store.containsKey(key);

  @override
  Future<Map<String, Object?>> getAll({Set<String>? allowList}) async {
    if (allowList == null) {
      return Map<String, Object?>.from(_store);
    }
    final filtered = <String, Object?>{};
    for (final key in allowList) {
      if (_store.containsKey(key)) {
        filtered[key] = _store[key];
      }
    }
    return filtered;
  }

  @override
  Future<bool?> getBool(String key) async {
    final value = _store[key];
    if (value is bool) return value;
    return null;
  }

  @override
  Future<double?> getDouble(String key) async {
    final value = _store[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return null;
  }

  @override
  Future<int?> getInt(String key) async {
    final value = _store[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  @override
  Future<Set<String>> getKeys({Set<String>? allowList}) async {
    if (allowList == null) return _store.keys.toSet();
    return _store.keys.where(allowList.contains).toSet();
  }

  @override
  Future<String?> getString(String key) async {
    final value = _store[key];
    if (value is String) return value;
    return null;
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    final value = _store[key];
    if (value is List<String>) {
      return List<String>.from(value);
    }
    return null;
  }

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    _store[key] = value;
  }

  @override
  Future<void> setDouble(String key, double value) async {
    _store[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) async {
    _store[key] = value;
  }

  @override
  Future<void> setString(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    _store[key] = List<String>.from(value);
  }
}

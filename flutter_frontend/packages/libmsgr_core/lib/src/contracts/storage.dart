import 'dart:async';

/// Contract for secure key-value persistence (e.g. keychain).
abstract class SecureStorage {
  Future<bool> containsKey(String key);
  Future<String?> readValue(String key);
  Future<Map<String, String>> readAll();
  Future<void> writeValue(String key, String value);
  Future<void> deleteAll();
  Future<void> deleteKey(String key);
}

/// Contract mirroring the API surface of shared preferences/key-value stores.
abstract class KeyValueStore {
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

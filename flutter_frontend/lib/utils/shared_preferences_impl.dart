import 'package:libmsgr/libmsgr.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Due to the fact that SharedPreferencesAsync from a external package
/// don't implement ASharedPreferences, we need this dummy class to forward
/// all methods to the real implementation...
class SharedPreferencesImpl implements ASharedPreferences {
  final SharedPreferencesAsync asyncPrefs = SharedPreferencesAsync();

  @override
  Future<void> clear({Set<String>? allowList}) {
    return asyncPrefs.clear();
  }

  @override
  Future<bool> containsKey(String key) {
    return asyncPrefs.containsKey(key);
  }

  @override
  Future<Map<String, Object?>> getAll({Set<String>? allowList}) {
    return asyncPrefs.getAll(allowList: allowList);
  }

  @override
  Future<bool?> getBool(String key) {
    return asyncPrefs.getBool(key);
  }

  @override
  Future<double?> getDouble(String key) {
    return asyncPrefs.getDouble(key);
  }

  @override
  Future<int?> getInt(String key) {
    return asyncPrefs.getInt(key);
  }

  @override
  Future<Set<String>> getKeys({Set<String>? allowList}) {
    return asyncPrefs.getKeys(allowList: allowList);
  }

  @override
  Future<String?> getString(String key) {
    return asyncPrefs.getString(key);
  }

  @override
  Future<List<String>?> getStringList(String key) {
    return asyncPrefs.getStringList(key);
  }

  @override
  Future<void> remove(String key) {
    return asyncPrefs.remove(key);
  }

  @override
  Future<void> setBool(String key, bool value) {
    return asyncPrefs.setBool(key, value);
  }

  @override
  Future<void> setDouble(String key, double value) {
    return asyncPrefs.setDouble(key, value);
  }

  @override
  Future<void> setInt(String key, int value) {
    return asyncPrefs.setInt(key, value);
  }

  @override
  Future<void> setString(String key, String value) {
    return asyncPrefs.setString(key, value);
  }

  @override
  Future<void> setStringList(String key, List<String> value) {
    return asyncPrefs.setStringList(key, value);
  }
}

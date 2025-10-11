import 'dart:async';
import 'dart:io';

import 'package:libmsgr/libmsgr.dart';

/// In-memory [ASecureStorage] implementation used by the CLI tooling.
///
/// The integration tests and the command line utilities do not persist
/// anything between runs. Having an in-memory implementation makes the
/// behaviour explicit and avoids touching the developer's keychain.
class MemorySecureStorage implements ASecureStorage {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<bool> containsKey(dynamic key) async {
    return _values.containsKey(key as String);
  }

  @override
  Future<void> deleteAll() async {
    _values.clear();
  }

  @override
  Future<void> deleteKey(dynamic key) async {
    _values.remove(key as String);
  }

  @override
  Future<Map<String, String>> readAll() async {
    return Map<String, String>.from(_values);
  }

  @override
  Future<String?> readValue(dynamic key) async {
    return _values[key as String];
  }

  @override
  Future<String> writeValue(dynamic key, dynamic value) async {
    final stringKey = key as String;
    final stringValue = value as String;
    _values[stringKey] = stringValue;
    return stringValue;
  }
}

/// Minimal [ASharedPreferences] implementation backed by a `Map`.
///
/// The real mobile applications use the platform specific implementation but
/// for command line tooling we only need something that behaves close enough
/// for caching tokens inside libmsgr.
class MemorySharedPreferences implements ASharedPreferences {
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
  Future<bool> containsKey(String key) async {
    return _store.containsKey(key);
  }

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
    if (value is bool) {
      return value;
    }
    return null;
  }

  @override
  Future<double?> getDouble(String key) async {
    final value = _store[key];
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  @override
  Future<int?> getInt(String key) async {
    final value = _store[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  @override
  Future<Set<String>> getKeys({Set<String>? allowList}) async {
    if (allowList == null) {
      return _store.keys.toSet();
    }
    return _store.keys.where(allowList.contains).toSet();
  }

  @override
  Future<String?> getString(String key) async {
    final value = _store[key];
    if (value is String) {
      return value;
    }
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

/// Device information stub used when running in non mobile environments.
class FakeDeviceInfo implements ADeviceInfo {
  FakeDeviceInfo(this.deviceId);

  final String deviceId;

  Map<String, dynamic> get info => <String, dynamic>{
        'platform': 'integration-test',
        'platformVersion': Platform.version,
        'model': 'cli-driver',
        'os': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'deviceId': deviceId,
      };

  Future<Map<String, dynamic>> appInfo() async {
    return <String, dynamic>{
      'appName': 'integration-cli',
      'appVersion': '0.0.1',
      'buildNumber': 'test',
    };
  }

  @override
  Future<Map<dynamic, dynamic>> extractInformation() async {
    return Map<dynamic, dynamic>.from(info);
  }
}

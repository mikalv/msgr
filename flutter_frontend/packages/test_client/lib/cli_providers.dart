import 'dart:io';
import 'dart:convert';
import 'package:libmsgr/libmsgr.dart' show ADeviceInfo;
import 'package:libmsgr_core/libmsgr_core.dart';
import 'package:path/path.dart' as path;

/// CLI-compatible implementation of SecureStorage using a JSON file
class CliSecureStorage implements SecureStorage {
  final String _filePath;
  Map<String, String> _data = {};
  bool _loaded = false;

  CliSecureStorage(String storagePath)
      : _filePath = path.join(storagePath, 'secure_storage.json');

  Future<void> _ensureLoaded() async {
    if (_loaded) return;

    final file = File(_filePath);
    if (await file.exists()) {
      final contents = await file.readAsString();
      _data = Map<String, String>.from(json.decode(contents));
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final file = File(_filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(json.encode(_data));
  }

  @override
  Future<bool> containsKey(String key) async {
    await _ensureLoaded();
    return _data.containsKey(key);
  }

  @override
  Future<String?> readValue(String key) async {
    await _ensureLoaded();
    return _data[key];
  }

  @override
  Future<Map<String, String>> readAll() async {
    await _ensureLoaded();
    return Map.from(_data);
  }

  @override
  Future<void> writeValue(String key, String value) async {
    await _ensureLoaded();
    _data[key] = value;
    await _save();
  }

  @override
  Future<void> deleteAll() async {
    await _ensureLoaded();
    _data.clear();
    await _save();
  }

  @override
  Future<void> deleteKey(String key) async {
    await _ensureLoaded();
    _data.remove(key);
    await _save();
  }
}

/// CLI-compatible implementation of KeyValueStore using a JSON file
class CliKeyValueStore implements KeyValueStore {
  final String _filePath;
  Map<String, Object?> _data = {};
  bool _loaded = false;

  CliKeyValueStore(String storagePath)
      : _filePath = path.join(storagePath, 'key_value_store.json');

  Future<void> _ensureLoaded() async {
    if (_loaded) return;

    final file = File(_filePath);
    if (await file.exists()) {
      final contents = await file.readAsString();
      _data = Map<String, Object?>.from(json.decode(contents));
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final file = File(_filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(json.encode(_data));
  }

  @override
  Future<void> clear({Set<String>? allowList}) async {
    await _ensureLoaded();
    if (allowList == null) {
      _data.clear();
    } else {
      _data.removeWhere((key, value) => !allowList.contains(key));
    }
    await _save();
  }

  @override
  Future<bool> containsKey(String key) async {
    await _ensureLoaded();
    return _data.containsKey(key);
  }

  @override
  Future<Map<String, Object?>> getAll({Set<String>? allowList}) async {
    await _ensureLoaded();
    if (allowList == null) {
      return Map.from(_data);
    }
    return Map.fromEntries(
      _data.entries.where((entry) => allowList.contains(entry.key)),
    );
  }

  @override
  Future<bool?> getBool(String key) async {
    await _ensureLoaded();
    return _data[key] as bool?;
  }

  @override
  Future<double?> getDouble(String key) async {
    await _ensureLoaded();
    return _data[key] as double?;
  }

  @override
  Future<int?> getInt(String key) async {
    await _ensureLoaded();
    return _data[key] as int?;
  }

  @override
  Future<Set<String>> getKeys({Set<String>? allowList}) async {
    await _ensureLoaded();
    if (allowList == null) {
      return Set.from(_data.keys);
    }
    return Set.from(_data.keys.where((key) => allowList.contains(key)));
  }

  @override
  Future<String?> getString(String key) async {
    await _ensureLoaded();
    return _data[key] as String?;
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    await _ensureLoaded();
    final value = _data[key];
    if (value == null) return null;
    return List<String>.from(value as List);
  }

  @override
  Future<void> remove(String key) async {
    await _ensureLoaded();
    _data.remove(key);
    await _save();
  }

  @override
  Future<void> setBool(String key, bool value) async {
    await _ensureLoaded();
    _data[key] = value;
    await _save();
  }

  @override
  Future<void> setDouble(String key, double value) async {
    await _ensureLoaded();
    _data[key] = value;
    await _save();
  }

  @override
  Future<void> setInt(String key, int value) async {
    await _ensureLoaded();
    _data[key] = value;
    await _save();
  }

  @override
  Future<void> setString(String key, String value) async {
    await _ensureLoaded();
    _data[key] = value;
    await _save();
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    await _ensureLoaded();
    _data[key] = value;
    await _save();
  }
}

/// CLI-compatible implementation of DeviceInfoProvider
class CliDeviceInfo extends ADeviceInfo {
  @override
  Future<Map> extractInformation() async {
    return {
      'model': 'CLI',
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'deviceId': 'cli-device-${Platform.localHostname}',
    };
  }

  @override
  Future<Map<String, dynamic>> appInfo() async {
    return {
      'appName': 'LibMsgr CLI Test Client',
      'packageName': 'com.msgr.test_client',
      'version': '1.0.0',
      'buildNumber': '1',
    };
  }
}

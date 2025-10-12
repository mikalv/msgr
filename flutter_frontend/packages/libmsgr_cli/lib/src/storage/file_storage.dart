import 'dart:convert';
import 'dart:io';

import 'package:libmsgr_core/libmsgr_core.dart';
import 'package:path/path.dart' as p;

class FileSecureStorage implements SecureStorage {
  FileSecureStorage(this.root)
      : _file = File(p.join(root.path, 'secure.json'));

  final Directory root;
  final File _file;
  Map<String, String> _cache = <String, String>{};
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    if (await _file.exists()) {
      final content = await _file.readAsString();
      if (content.trim().isNotEmpty) {
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        _cache = decoded.map((key, value) => MapEntry(key, value as String));
      }
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    await _file.writeAsString(jsonEncode(_cache));
  }

  @override
  Future<bool> containsKey(String key) async {
    await _ensureLoaded();
    return _cache.containsKey(key);
  }

  @override
  Future<void> deleteAll() async {
    await _ensureLoaded();
    _cache.clear();
    await _persist();
  }

  @override
  Future<void> deleteKey(String key) async {
    await _ensureLoaded();
    _cache.remove(key);
    await _persist();
  }

  @override
  Future<Map<String, String>> readAll() async {
    await _ensureLoaded();
    return Map<String, String>.from(_cache);
  }

  @override
  Future<String?> readValue(String key) async {
    await _ensureLoaded();
    return _cache[key];
  }

  @override
  Future<void> writeValue(String key, String value) async {
    await _ensureLoaded();
    _cache[key] = value;
    await _persist();
  }
}

class FileKeyValueStore implements KeyValueStore {
  FileKeyValueStore(this.root)
      : _file = File(p.join(root.path, 'prefs.json'));

  final Directory root;
  final File _file;
  Map<String, Object?> _cache = <String, Object?>{};
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    if (await _file.exists()) {
      final content = await _file.readAsString();
      if (content.trim().isNotEmpty) {
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        _cache = Map<String, Object?>.from(decoded);
      }
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    await _file.writeAsString(jsonEncode(_cache));
  }

  @override
  Future<void> clear({Set<String>? allowList}) async {
    await _ensureLoaded();
    if (allowList == null) {
      _cache.clear();
    } else {
      _cache.removeWhere((key, _) => !allowList.contains(key));
    }
    await _persist();
  }

  @override
  Future<bool> containsKey(String key) async {
    await _ensureLoaded();
    return _cache.containsKey(key);
  }

  @override
  Future<Map<String, Object?>> getAll({Set<String>? allowList}) async {
    await _ensureLoaded();
    if (allowList == null) {
      return Map<String, Object?>.from(_cache);
    }
    final filtered = <String, Object?>{};
    for (final key in allowList) {
      if (_cache.containsKey(key)) {
        filtered[key] = _cache[key];
      }
    }
    return filtered;
  }

  @override
  Future<bool?> getBool(String key) async {
    await _ensureLoaded();
    final value = _cache[key];
    return value is bool ? value : null;
  }

  @override
  Future<double?> getDouble(String key) async {
    await _ensureLoaded();
    final value = _cache[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return null;
  }

  @override
  Future<int?> getInt(String key) async {
    await _ensureLoaded();
    final value = _cache[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  @override
  Future<Set<String>> getKeys({Set<String>? allowList}) async {
    await _ensureLoaded();
    final keys = _cache.keys;
    if (allowList == null) {
      return keys.toSet();
    }
    return keys.where(allowList.contains).toSet();
  }

  @override
  Future<String?> getString(String key) async {
    await _ensureLoaded();
    final value = _cache[key];
    return value is String ? value : null;
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    await _ensureLoaded();
    final value = _cache[key];
    if (value is List) {
      return value.map((element) => element.toString()).toList();
    }
    return null;
  }

  @override
  Future<void> remove(String key) async {
    await _ensureLoaded();
    _cache.remove(key);
    await _persist();
  }

  @override
  Future<void> setBool(String key, bool value) async {
    await _ensureLoaded();
    _cache[key] = value;
    await _persist();
  }

  @override
  Future<void> setDouble(String key, double value) async {
    await _ensureLoaded();
    _cache[key] = value;
    await _persist();
  }

  @override
  Future<void> setInt(String key, int value) async {
    await _ensureLoaded();
    _cache[key] = value;
    await _persist();
  }

  @override
  Future<void> setString(String key, String value) async {
    await _ensureLoaded();
    _cache[key] = value;
    await _persist();
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    await _ensureLoaded();
    _cache[key] = List<String>.from(value);
    await _persist();
  }
}

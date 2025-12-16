import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:logging/logging.dart';

class SecureStore implements ASecureStorage {
  static final SecureStore _singleton = SecureStore._internal();
  final Logger _log = Logger('SecureStore');
  late FlutterSecureStorage storage;

  SecureStore._internal() {
    _log.info('SecureStore starting up');
    if (kIsWeb) {
      storage = const FlutterSecureStorage();
    } else {
      if (Platform.isAndroid) {
        storage = FlutterSecureStorage(aOptions: _getAndroidOptions());
      } else {
        storage = const FlutterSecureStorage();
      }
    }
  }

  factory SecureStore() {
    return _singleton;
  }

  AndroidOptions _getAndroidOptions() => const AndroidOptions(
        encryptedSharedPreferences: true,
      );

  @override
  Future<bool> containsKey(key) async {
    if (kIsWeb) {
      return await storage.containsKey(key: key);
    }
    if (Platform.isIOS) {
      const options =
          IOSOptions(accessibility: KeychainAccessibility.first_unlock);
      return await storage.containsKey(key: key, iOptions: options);
    } else {
      return await storage.containsKey(key: key);
    }
  }

  @override
  Future<String?> readValue(key) async {
    if (kIsWeb) {
      return await storage.read(key: key);
    }
    if (Platform.isIOS) {
      const options =
          IOSOptions(accessibility: KeychainAccessibility.first_unlock);
      var value = await storage.read(key: key, iOptions: options);
      _log.finest('readValue($key) -> $value');
      return value;
    } else {
      var value = await storage.read(key: key);
      _log.finest('readValue($key) -> $value');
      return value;
    }
  }

  @override
  Future<Map<String, String>> readAll() async {
    return await storage.readAll();
  }

  @override
  Future<String> writeValue(key, value) async {
    _log.finest('writeValue($key, $value)');
    if (kIsWeb) {
      await storage.write(key: key, value: value);
      return value;
    }
    if (Platform.isIOS) {
      const options =
          IOSOptions(accessibility: KeychainAccessibility.first_unlock);
      await storage.write(key: key, value: value, iOptions: options);
    } else {
      await storage.write(key: key, value: value);
    }
    return value;
  }

  @override
  deleteAll() async {
    await storage.deleteAll();
  }

  @override
  deleteKey(key) async {
    await storage.delete(key: key);
  }
}

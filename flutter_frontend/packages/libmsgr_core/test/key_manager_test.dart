import 'dart:convert';

import 'package:libmsgr_core/libmsgr_core.dart';
import 'package:test/test.dart';

class InMemorySecureStorage implements SecureStorage {
  InMemorySecureStorage({Map<String, String>? seed})
      : _store = Map<String, String>.from(seed ?? const {});

  final Map<String, String> _store;

  Map<String, String> get snapshot => Map.unmodifiable(_store);

  @override
  Future<void> deleteAll() async {
    _store.clear();
  }

  @override
  Future<void> deleteKey(String key) async {
    _store.remove(key);
  }

  @override
  Future<bool> containsKey(String key) async => _store.containsKey(key);

  @override
  Future<Map<String, String>> readAll() async => Map<String, String>.from(_store);

  @override
  Future<String?> readValue(String key) async => _store[key];

  @override
  Future<void> writeValue(String key, String value) async {
    _store[key] = value;
  }
}

void main() {
  group('KeyManager', () {
    test('creates new device when storage is empty', () async {
      final storage = InMemorySecureStorage();
      final keyManager = KeyManager(storage: storage);

      await keyManager.getOrGenerateDeviceId();

      expect(storage.snapshot['deviceId'], isNotEmpty);
      final encodedKeys = storage.snapshot['deviceKeys'];
      expect(encodedKeys, isNotNull);

      final payload = json.decode(encodedKeys!) as Map<String, dynamic>;
      expect(payload['deviceId'], keyManager.deviceId);
      expect(keyManager.deviceId, isNotEmpty);
      expect(keyManager.isLoading, isFalse);
    });

    test('loads stored keys when present', () async {
      final priv = base64.encode(List<int>.filled(32, 1));
      final dhPriv = base64.encode(List<int>.filled(32, 2));
      final storedPayload = json.encode({
        'signingKeys': {'privkey': priv, 'pubkey': priv},
        'dhKeys': {'privkey': dhPriv, 'pubkey': dhPriv},
        'deviceId': 'abc'
      });

      final storage = InMemorySecureStorage(seed: {
        'deviceId': 'abc',
        'deviceKeys': storedPayload,
      });
      final keyManager = KeyManager(storage: storage);

      await keyManager.getOrGenerateDeviceId();

      expect(keyManager.deviceId, 'abc');
      expect(keyManager.isLoading, isFalse);
    });

    test('getDataForServer throws while loading', () {
      final storage = InMemorySecureStorage();
      final keyManager = KeyManager(storage: storage);

      keyManager.isLoading = true;
      expect(() => keyManager.getDataForServer(), throwsStateError);
    });

    test('getDataForServer returns signatures when loaded', () async {
      final storage = InMemorySecureStorage();
      final keyManager = KeyManager(storage: storage);

      keyManager.isLoading = false;
      keyManager.deviceId = 'abc';
      keyManager.signingKeyPair = await keyManager.signAlgorithm.newKeyPair();
      keyManager.dhKeyPair = await keyManager.dhAlgorithm.newKeyPair();

      final payload = await keyManager.getDataForServer();
      expect(payload['deviceId'], 'abc');
      expect(payload['pubkey'], isNotEmpty);
      expect(payload['dhpubkey'], isNotEmpty);
    });
  });
}

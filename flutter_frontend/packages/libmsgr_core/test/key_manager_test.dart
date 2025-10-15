import 'dart:convert';

import 'package:libmsgr_core/libmsgr_core.dart';
import 'package:test/test.dart';

void main() {
  group('KeyManager', () {
    test('creates new device when storage is empty', () async {
      final storage = MemorySecureStorage();
      final keyManager = KeyManager(storage: storage);

      await keyManager.getOrGenerateDeviceId();

      final deviceId = await storage.readValue('deviceId');
      expect(deviceId, isNotNull);
      expect(deviceId, isNotEmpty);

      final encodedKeys = await storage.readValue('deviceKeys');
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

      final storage = MemorySecureStorage();
      await storage.writeValue('deviceId', 'abc');
      await storage.writeValue('deviceKeys', storedPayload);
      final keyManager = KeyManager(storage: storage);

      await keyManager.getOrGenerateDeviceId();

      expect(keyManager.deviceId, 'abc');
      expect(keyManager.isLoading, isFalse);
    });

    test('getDataForServer throws while loading', () {
      final storage = MemorySecureStorage();
      final keyManager = KeyManager(storage: storage);

      keyManager.isLoading = true;
      expect(() => keyManager.getDataForServer(), throwsStateError);
    });

    test('getDataForServer returns signatures when loaded', () async {
      final storage = MemorySecureStorage();
      final keyManager = KeyManager(storage: storage);

      await keyManager.getOrGenerateDeviceId();

      final payload = await keyManager.getDataForServer();
      expect(payload['deviceId'], keyManager.deviceId);
      expect(payload['pubkey'], isNotEmpty);
      expect(payload['dhpubkey'], isNotEmpty);
    });
  });
}

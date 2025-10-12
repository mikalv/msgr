import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:libmsgr_core/libmsgr_core.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  group('KeyManager', () {
    late KeyManager keyManager;
    late MockSecureStorage storage;

    setUp(() {
      storage = MockSecureStorage();
      keyManager = KeyManager(storage: storage);
    });

    test('creates new device when storage is empty', () async {
      when(storage.containsKey('deviceId')).thenAnswer((_) async => false);
      when(storage.writeValue(any<String>(), any<String>()))
          .thenAnswer((_) async {});

      await keyManager.getOrGenerateDeviceId();

      verify(storage.writeValue('deviceId', any<String>())).called(1);
      verify(storage.writeValue('deviceKeys', any<String>())).called(1);
      expect(keyManager.deviceId, isNotEmpty);
      expect(keyManager.isLoading, isFalse);
    });

    test('loads stored keys when present', () async {
      final priv = base64.encode(List.filled(32, 1));
      final dhPriv = base64.encode(List.filled(32, 2));

      when(storage.containsKey('deviceId')).thenAnswer((_) async => true);
      when(storage.readValue('deviceId')).thenAnswer((_) async => 'abc');
      when(storage.readValue('deviceKeys')).thenAnswer((_) async => json.encode({
            'signingKeys': {'privkey': priv, 'pubkey': priv},
            'dhKeys': {'privkey': dhPriv, 'pubkey': dhPriv},
            'deviceId': 'abc'
          }));

      await keyManager.getOrGenerateDeviceId();

      verify(storage.readValue('deviceId')).called(1);
      verify(storage.readValue('deviceKeys')).called(1);
      expect(keyManager.deviceId, 'abc');
      expect(keyManager.isLoading, isFalse);
    });

    test('getDataForServer throws while loading', () {
      keyManager.isLoading = true;
      expect(() => keyManager.getDataForServer(), throwsStateError);
    });

    test('getDataForServer returns signatures when loaded', () async {
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

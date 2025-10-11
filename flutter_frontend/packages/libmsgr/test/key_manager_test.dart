import 'package:flutter_test/flutter_test.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:mockito/mockito.dart';
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:logging/logging.dart';
import '../lib/src/key_manager.dart';

// Mock class for ASecureStorage
class MockSecureStorage extends Mock implements ASecureStorage {}

void main() {
  group('KeyManager Tests', () {
    late KeyManager keyManager;
    late MockSecureStorage mockStorage;

    setUp(() {
      mockStorage = MockSecureStorage();
      keyManager = KeyManager(storage: mockStorage);
    });

    test('getOrGenerateDeviceId generates new deviceId if not present',
        () async {
      when(mockStorage.containsKey('deviceId')).thenAnswer((_) async => false);
      when(mockStorage.writeValue(any, any))
          .thenAnswer((_) async => Future.value(''));

      await keyManager.getOrGenerateDeviceId();

      verify(mockStorage.writeValue('deviceId', any)).called(1);
      verify(mockStorage.writeValue('deviceKeys', any)).called(1);
      expect(keyManager.deviceId, isNotNull);
      expect(keyManager.isLoading, isFalse);
    });

    test('getOrGenerateDeviceId loads existing deviceId if present', () async {
      when(mockStorage.containsKey('deviceId')).thenAnswer((_) async => true);
      when(mockStorage.readValue('deviceId'))
          .thenAnswer((_) async => 'test-device-id');
      when(mockStorage.readValue('deviceKeys'))
          .thenAnswer((_) async => json.encode({
                'signingKeys': {
                  'privkey': base64.encode(List<int>.filled(32, 1)),
                  'pubkey': base64.encode(List<int>.filled(32, 2)),
                },
                'dhKeys': {
                  'privkey': base64.encode(List<int>.filled(32, 3)),
                  'pubkey': base64.encode(List<int>.filled(32, 4)),
                },
                'deviceId': 'test-device-id'
              }));

      await keyManager.getOrGenerateDeviceId();

      verify(mockStorage.readValue('deviceId')).called(1);
      verify(mockStorage.readValue('deviceKeys')).called(1);
      expect(keyManager.deviceId, 'test-device-id');
      expect(keyManager.isLoading, isFalse);
    });

    test('getDataForServer throws error if KeyManager is still loading',
        () async {
      keyManager.isLoading = true;

      expect(() => keyManager.getDataForServer(), throwsA(isA<String>()));
    });

    test('getDataForServer returns correct data when loaded', () async {
      keyManager.isLoading = false;
      keyManager.deviceId = 'test-device-id';
      keyManager.signingKeyPair = await keyManager.signAlgorithm.newKeyPair();
      keyManager.dhKeyPair = await keyManager.dhAlgorithm.newKeyPair();

      var data = await keyManager.getDataForServer();

      expect(data['deviceId'], 'test-device-id');
      expect(data['pubkey'], isNotNull);
      expect(data['signature'], isNotNull);
      expect(data['dhpubkey'], isNotNull);
    });
  });
}

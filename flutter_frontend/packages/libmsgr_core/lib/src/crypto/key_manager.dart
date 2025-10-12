import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

import '../constants.dart';
import '../contracts/storage.dart';

class KeyManager {
  KeyManager({required SecureStorage storage})
      : storage = storage,
        _log = Logger('KeyManager');

  final Logger _log;
  final SecureStorage storage;

  final SignatureAlgorithm signAlgorithm = Ed25519();
  final KeyExchangeAlgorithm dhAlgorithm = X25519();

  late KeyPair signingKeyPair;
  late KeyPair dhKeyPair;
  late String deviceId;
  bool isLoading = true;

  Future<void> getOrGenerateDeviceId() async {
    final hasDeviceId = await storage.containsKey('deviceId');
    if (hasDeviceId) {
      await _loadFromSecureStorage();
      _log.info('Loaded deviceId and keys from secure storage. deviceId: $deviceId');
    } else {
      await _createNewDevice();
      _log.info('Generated new deviceId and keys. deviceId: $deviceId');
    }
    isLoading = false;
  }

  Future<Map<String, dynamic>> getDataForServer() async {
    if (isLoading) {
      throw StateError('KeyManager is still loading keys');
    }

    final signature = await signAlgorithm.signString(
      deviceId,
      keyPair: signingKeyPair,
    );

    final publicKey = await signingKeyPair.extractPublicKey() as SimplePublicKey;
    final dhPublicKey = await dhKeyPair.extractPublicKey() as SimplePublicKey;

    return <String, dynamic>{
      'pubkey': base64.encode(publicKey.bytes),
      'signature': base64.encode(signature.bytes),
      'dhpubkey': base64.encode(dhPublicKey.bytes),
      'deviceId': deviceId,
    };
  }

  Future<void> _loadFromSecureStorage() async {
    final storedDeviceId = await storage.readValue('deviceId');
    if (storedDeviceId == null) {
      throw StateError('deviceId missing from secure storage');
    }
    deviceId = storedDeviceId;

    final keyPayload = await storage.readValue('deviceKeys');
    if (keyPayload == null) {
      if (MsgrConstants.localDevelopment) {
        await storage.deleteAll();
        _log.warning(
          'Deleted secure storage data as it seemed corrupted (development mode only)',
        );
        exit(0);
      }
      throw StateError('deviceKeys missing from secure storage');
    }

    final decoded = (json.decode(keyPayload) as Map<String, dynamic>);

    final signingKeys = decoded['signingKeys'] as Map<String, dynamic>;
    final dhKeys = decoded['dhKeys'] as Map<String, dynamic>;

    signingKeyPair = await signAlgorithm.newKeyPairFromSeed(
      base64.decode(signingKeys['privkey'] as String),
    ) as KeyPair;

    dhKeyPair = await dhAlgorithm.newKeyPairFromSeed(
      base64.decode(dhKeys['privkey'] as String),
    ) as KeyPair;
  }

  Future<void> _createNewDevice() async {
    final did = const Uuid().v4();
    deviceId = did;

    final signingKeys = await _generateSigningKeyPair();
    final dhKeys = await _generateDhKeyPair();

    final payload = <String, dynamic>{
      'signingKeys': {
        'privkey': base64.encode(signingKeys['privkey'] as List<int>),
        'pubkey': base64.encode(signingKeys['pubkey'] as List<int>),
      },
      'dhKeys': {
        'privkey': base64.encode(dhKeys['privkey'] as List<int>),
        'pubkey': base64.encode(dhKeys['pubkey'] as List<int>),
      },
      'deviceId': did,
    };

    await storage.writeValue('deviceId', did);
    await storage.writeValue('deviceKeys', json.encode(payload));
  }

  Future<Map<String, Object>> _generateSigningKeyPair() async {
    final keyPair = await signAlgorithm.newKeyPair();
    final privKey = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    signingKeyPair = keyPair;
    _log.fine('Generated signing key pair');
    return <String, Object>{
      'keyPair': keyPair,
      'privkey': privKey,
      'pubkey': publicKey.bytes,
    };
  }

  Future<Map<String, Object>> _generateDhKeyPair() async {
    final keyPair = await dhAlgorithm.newKeyPair();
    final privKey = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    dhKeyPair = keyPair;
    _log.fine('Generated DH key pair');
    return <String, Object>{
      'keyPair': keyPair,
      'privkey': privKey,
      'pubkey': publicKey.bytes,
    };
  }
}

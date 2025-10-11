import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

class KeyManager {
  final Logger _log = Logger('KeyManager');
  final signAlgorithm = Ed25519();
  final dhAlgorithm = X25519();
  ASecureStorage storage;
  late KeyPair signingKeyPair;
  late KeyPair dhKeyPair;
  late String deviceId;
  bool isLoading = true;

  KeyManager({required this.storage}) {
    _log.info('KeyManager starting up');
  }

  getOrGenerateDeviceId() async {
    bool hasDeviceId = await storage.containsKey("deviceId");
    dynamic result;
    if (hasDeviceId) {
      result = await _loadFromSecureStorage();
      _log.info(
          'Loaded deviceId and keys from secure storage. deviceId: $deviceId');
    } else {
      result = await _newDeviceFn();
      _log.info('Generated new deviceId and keys. deviceId: $deviceId');
    }
    isLoading = false;
    return result;
  }

  Future<Map<String, Object>> _generateSigningKeyPair(did) async {
    final keyPair = await signAlgorithm.newKeyPair();
    var privkey = await keyPair.extractPrivateKeyBytes();
    var pubkey = await keyPair.extractPublicKey();
    signingKeyPair = keyPair;
    var data = {
      'keyPair': keyPair,
      'privkey': privkey,
      'pubkey': pubkey.bytes,
    };
    _log.info('Generated Signing keys publickey=$pubkey');
    return data;
  }

  Future<Map<String, Object>> _generateDhKeyPair() async {
    final initialMeKeyPair = await dhAlgorithm.newKeyPair();
    var privkey = await initialMeKeyPair.extractPrivateKeyBytes();
    var pubkey = await initialMeKeyPair.extractPublicKey();
    dhKeyPair = initialMeKeyPair;
    var data = {
      'keyPair': initialMeKeyPair,
      'privkey': privkey,
      'pubkey': pubkey.bytes,
    };
    _log.info('Generated DH keys publickey=$pubkey');
    return data;
  }

  Future<Map<String, String>> getDataForServer() async {
    if (isLoading) {
      throw 'KeyManager isn\'t done loading yet!';
    }
    //deviceId = (await storage.readValue('deviceId'))!;
    final signature = await signAlgorithm.signString(
      deviceId,
      keyPair: signingKeyPair,
    );
    SimplePublicKey publicKey =
        await signingKeyPair.extractPublicKey() as SimplePublicKey;
    SimplePublicKey dhPublicKey =
        await dhKeyPair.extractPublicKey() as SimplePublicKey;
    var forServer = {
      'pubkey': base64.encode(publicKey.bytes),
      'signature': base64.encode(signature.bytes),
      'dhpubkey': base64.encode(dhPublicKey.bytes),
      'deviceId': deviceId
    };
    return forServer;
  }

  _loadFromSecureStorage() async {
    final signAlgorithm = Ed25519();
    final dhAlgorithm = X25519();
    deviceId = (await storage.readValue('deviceId'))!;
    _log.finest('Reading in $deviceId');
    var jdata = await storage.readValue("deviceKeys");
    if (jdata == null) {
      if (localDevelopment) {
        storage.deleteAll();
        _log.warning(
            'Deleted all secure storage data as it seemed corrupted. Only doing this in development mode :)');
        exit(0);
      }
      throw 'Error reading deviceKeys from secure storage';
    }
    // TODO: Handle error here when data store is corrupted
    var data = json.decode(jdata!);
    var skdata = data!['signingKeys'];
    var dhdata = data!['dhKeys'];
    signingKeyPair = await signAlgorithm
        .newKeyPairFromSeed(base64.decode(skdata['privkey'])) as KeyPair;
    dhKeyPair = await dhAlgorithm
        .newKeyPairFromSeed(base64.decode(dhdata['privkey'])) as KeyPair;
    _log.info('Loaded cryptographic keys from secure storage.');
    return data;
  }

  _newDeviceFn() async {
    var did = Uuid().v4();
    deviceId = did;
    var signingKeys = await _generateSigningKeyPair(did);
    var dhKeys = await _generateDhKeyPair();
    var forStorage = {
      'signingKeys': {
        'privkey': base64.encode(signingKeys['privkey'] as List<int>),
        'pubkey': base64.encode(signingKeys['pubkey'] as List<int>),
      },
      'dhKeys': {
        'privkey': base64.encode(dhKeys['privkey'] as List<int>),
        'pubkey': base64.encode(dhKeys['pubkey'] as List<int>),
      },
      'deviceId': did
    };
    var jdata = json.encode(forStorage);
    await storage.writeValue("deviceId", did);
    await storage.writeValue("deviceKeys", jdata);
    _log.info('Created new deviceId ($deviceId) and keys');
    return forStorage;
  }
}

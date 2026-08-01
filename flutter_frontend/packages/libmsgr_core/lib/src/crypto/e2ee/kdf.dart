import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// HKDF / HMAC helpers for msgr E2EE.
class E2eeKdf {
  E2eeKdf._();

  static final Hkdf _hkdf32 = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static final Hkdf _hkdf64 = Hkdf(hmac: Hmac.sha256(), outputLength: 64);
  static final Hkdf _hkdf44 = Hkdf(hmac: Hmac.sha256(), outputLength: 44);
  static final Hmac _hmac = Hmac.sha256();

  static final Uint8List zeroSalt32 = Uint8List(32);

  static Future<Uint8List> hkdf({
    required List<int> ikm,
    required List<int> info,
    List<int>? salt,
    required int length,
  }) async {
    final hkdf = length == 32
        ? _hkdf32
        : length == 64
            ? _hkdf64
            : length == 44
                ? _hkdf44
                : Hkdf(hmac: Hmac.sha256(), outputLength: length);
    final derived = await hkdf.deriveKey(
      secretKey: SecretKey(ikm),
      nonce: salt ?? zeroSalt32,
      info: info,
    );
    return Uint8List.fromList(derived.bytes);
  }

  static Future<Uint8List> deriveXxSharedSecret(Uint8List ikm) {
    return hkdf(
      ikm: ikm,
      info: utf8Bytes('msgr-e2ee-xx-v1'),
      length: 32,
    );
  }

  static Future<Uint8List> deriveX3dhSharedSecret(Uint8List ikm) {
    return hkdf(
      ikm: ikm,
      info: utf8Bytes('msgr-e2ee-x3dh-v1'),
      length: 32,
    );
  }

  /// KDF_RK → (new root key, chain key), each 32 bytes.
  static Future<(Uint8List, Uint8List)> kdfRk({
    required Uint8List rootKey,
    required Uint8List dhOut,
  }) async {
    final out = await hkdf(
      ikm: dhOut,
      salt: rootKey,
      info: utf8Bytes('msgr-e2ee-root-v1'),
      length: 64,
    );
    return (out.sublist(0, 32), out.sublist(32, 64));
  }

  /// KDF_CK → (message key, next chain key).
  static Future<(Uint8List, Uint8List)> kdfCk(Uint8List chainKey) async {
    final mkMac = await _hmac.calculateMac(
      const <int>[0x01],
      secretKey: SecretKey(chainKey),
    );
    final ckMac = await _hmac.calculateMac(
      const <int>[0x02],
      secretKey: SecretKey(chainKey),
    );
    return (
      Uint8List.fromList(mkMac.bytes),
      Uint8List.fromList(ckMac.bytes),
    );
  }

  /// Expand message key → 32B AES key + 12B nonce.
  static Future<(Uint8List, Uint8List)> expandMessageKey(Uint8List mk) async {
    final out = await hkdf(
      ikm: mk,
      info: utf8Bytes('msgr-e2ee-msg-v1'),
      length: 44,
    );
    return (out.sublist(0, 32), out.sublist(32, 44));
  }

  static Uint8List utf8Bytes(String value) =>
      Uint8List.fromList(utf8.encode(value));
}

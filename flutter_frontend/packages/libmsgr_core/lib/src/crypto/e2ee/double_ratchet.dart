import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'kdf.dart';
import 'types.dart';

const int kMaxSkip = 1000;

class RatchetMessage {
  const RatchetMessage({
    required this.header,
    required this.ciphertext,
  });

  final RatchetHeader header;
  final Uint8List ciphertext;
}

/// Double Ratchet session state (docs/e2ee_spec.md §3).
class RatchetSession {
  RatchetSession._({
    required this.rootKey,
    required this.localIdentityPublic,
    required this.remoteIdentityPublic,
    required this.dhsPrivate,
    required this.dhsPublic,
    this.dhr,
    this.cks,
    this.ckr,
    this.ns = 0,
    this.nr = 0,
    this.pn = 0,
    Map<String, Uint8List>? skipped,
  }) : skipped = skipped ?? <String, Uint8List>{};

  Uint8List rootKey;
  final Uint8List localIdentityPublic;
  final Uint8List remoteIdentityPublic;
  Uint8List dhsPrivate;
  Uint8List dhsPublic;
  Uint8List? dhr;
  Uint8List? cks;
  Uint8List? ckr;
  int ns;
  int nr;
  int pn;
  final Map<String, Uint8List> skipped;

  static final X25519 _x25519 = X25519();
  static final AesGcm _aesGcm = AesGcm.with256bits();

  /// Alice (initiator) after XX finish: DHr = Bob's EK, fresh DHs, derive CKs.
  static Future<RatchetSession> initiatorFromSharedSecret({
    required Uint8List sharedSecret,
    required Uint8List localIdentityPublic,
    required Uint8List remoteIdentityPublic,
    required Uint8List remoteEphemeralPublic,
  }) async {
    final dhs = await _x25519.newKeyPair();
    final dhsPub = await dhs.extractPublicKey();
    final dhsPriv = await dhs.extractPrivateKeyBytes();
    final dhOut = await _dhWithPair(dhs, remoteEphemeralPublic);
    final (rk, cks) = await E2eeKdf.kdfRk(rootKey: sharedSecret, dhOut: dhOut);

    return RatchetSession._(
      rootKey: rk,
      localIdentityPublic: localIdentityPublic,
      remoteIdentityPublic: remoteIdentityPublic,
      dhsPrivate: Uint8List.fromList(dhsPriv),
      dhsPublic: Uint8List.fromList(dhsPub.bytes),
      dhr: remoteEphemeralPublic,
      cks: cks,
    );
  }

  /// Bob (responder) after XX complete: DHs = his EK; wait for Alice's first msg.
  static Future<RatchetSession> responderFromSharedSecret({
    required Uint8List sharedSecret,
    required Uint8List localIdentityPublic,
    required Uint8List remoteIdentityPublic,
    required Uint8List localEphemeralPrivate,
    required Uint8List localEphemeralPublic,
  }) async {
    return RatchetSession._(
      rootKey: Uint8List.fromList(sharedSecret),
      localIdentityPublic: localIdentityPublic,
      remoteIdentityPublic: remoteIdentityPublic,
      dhsPrivate: localEphemeralPrivate,
      dhsPublic: localEphemeralPublic,
    );
  }

  Future<RatchetMessage> encrypt(Uint8List plaintext) async {
    if (cks == null) {
      throw StateError('Sending chain not initialized');
    }
    final (mk, nextCk) = await E2eeKdf.kdfCk(cks!);
    cks = nextCk;
    final header = RatchetHeader(dh: dhsPublic, pn: pn, n: ns);
    ns += 1;
    final ad = _associatedDataForSend(header);
    final ciphertext = await _encryptWithMk(mk, plaintext, ad);
    return RatchetMessage(header: header, ciphertext: ciphertext);
  }

  Future<Uint8List> decrypt(RatchetMessage message) async {
    final skippedPlain = await _decryptSkipped(message);
    if (skippedPlain != null) {
      return skippedPlain;
    }

    if (dhr == null || !_bytesEqual(message.header.dh, dhr!)) {
      await _skipMessageKeys(message.header.pn);
      await _dhRatchet(message.header);
    }
    await _skipMessageKeys(message.header.n);
    if (ckr == null) {
      throw StateError('Receiving chain not initialized');
    }
    final (mk, nextCk) = await E2eeKdf.kdfCk(ckr!);
    ckr = nextCk;
    nr += 1;
    final ad = _associatedDataForReceive(message.header);
    return _decryptWithMk(mk, message.ciphertext, ad);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'root_key': base64Encode(rootKey),
        'local_ik': base64Encode(localIdentityPublic),
        'remote_ik': base64Encode(remoteIdentityPublic),
        'dhs_private': base64Encode(dhsPrivate),
        'dhs_public': base64Encode(dhsPublic),
        'dhr': dhr == null ? null : base64Encode(dhr!),
        'cks': cks == null ? null : base64Encode(cks!),
        'ckr': ckr == null ? null : base64Encode(ckr!),
        'ns': ns,
        'nr': nr,
        'pn': pn,
        'skipped': skipped.map(
          (k, v) => MapEntry(k, base64Encode(v)),
        ),
      };

  factory RatchetSession.fromJson(Map<String, dynamic> json) {
    Uint8List? opt(dynamic v) =>
        v == null ? null : Uint8List.fromList(base64Decode(v as String));
    final skippedRaw = json['skipped'] as Map<String, dynamic>? ?? const {};
    return RatchetSession._(
      rootKey: Uint8List.fromList(base64Decode(json['root_key'] as String)),
      localIdentityPublic:
          Uint8List.fromList(base64Decode(json['local_ik'] as String)),
      remoteIdentityPublic:
          Uint8List.fromList(base64Decode(json['remote_ik'] as String)),
      dhsPrivate:
          Uint8List.fromList(base64Decode(json['dhs_private'] as String)),
      dhsPublic: Uint8List.fromList(base64Decode(json['dhs_public'] as String)),
      dhr: opt(json['dhr']),
      cks: opt(json['cks']),
      ckr: opt(json['ckr']),
      ns: json['ns'] as int? ?? 0,
      nr: json['nr'] as int? ?? 0,
      pn: json['pn'] as int? ?? 0,
      skipped: skippedRaw.map(
        (k, v) => MapEntry(k, Uint8List.fromList(base64Decode(v as String))),
      ),
    );
  }

  Future<void> _dhRatchet(RatchetHeader header) async {
    pn = ns;
    ns = 0;
    nr = 0;
    dhr = header.dh;
    final dhOutRecv = await _dhWithPriv(dhsPrivate, dhr!);
    final (rk1, newCkr) = await E2eeKdf.kdfRk(rootKey: rootKey, dhOut: dhOutRecv);
    rootKey = rk1;
    ckr = newCkr;

    final newDhs = await _x25519.newKeyPair();
    final newPub = await newDhs.extractPublicKey();
    final newPriv = await newDhs.extractPrivateKeyBytes();
    dhsPrivate = Uint8List.fromList(newPriv);
    dhsPublic = Uint8List.fromList(newPub.bytes);

    final dhOutSend = await _dhWithPair(newDhs, dhr!);
    final (rk2, newCks) = await E2eeKdf.kdfRk(rootKey: rootKey, dhOut: dhOutSend);
    rootKey = rk2;
    cks = newCks;
  }

  Future<void> _skipMessageKeys(int until) async {
    if (ckr == null) return;
    if (nr + kMaxSkip < until) {
      throw StateError('Too many skipped message keys');
    }
    while (nr < until) {
      final (mk, nextCk) = await E2eeKdf.kdfCk(ckr!);
      ckr = nextCk;
      final key = _skipKey(dhr!, nr);
      skipped[key] = mk;
      nr += 1;
    }
  }

  Future<Uint8List?> _decryptSkipped(RatchetMessage message) async {
    final key = _skipKey(message.header.dh, message.header.n);
    final mk = skipped.remove(key);
    if (mk == null) return null;
    final ad = _associatedDataForReceive(message.header);
    return _decryptWithMk(mk, message.ciphertext, ad);
  }

  /// AD = sender_ik || recipient_ik || header (encryptor is sender).
  Uint8List _associatedDataForSend(RatchetHeader header) {
    final out = Uint8List(64 + 40);
    out.setAll(0, localIdentityPublic);
    out.setAll(32, remoteIdentityPublic);
    out.setAll(64, header.encode());
    return out;
  }

  /// AD = sender_ik || recipient_ik || header (decryptor is recipient).
  Uint8List _associatedDataForReceive(RatchetHeader header) {
    final out = Uint8List(64 + 40);
    out.setAll(0, remoteIdentityPublic);
    out.setAll(32, localIdentityPublic);
    out.setAll(64, header.encode());
    return out;
  }

  static String _skipKey(Uint8List dh, int n) => '${base64Encode(dh)}:$n';

  static Future<Uint8List> _dhWithPair(
    SimpleKeyPair pair,
    Uint8List remotePublic,
  ) async {
    final secret = await _x25519.sharedSecretKey(
      keyPair: pair,
      remotePublicKey: SimplePublicKey(remotePublic, type: KeyPairType.x25519),
    );
    return Uint8List.fromList(await secret.extractBytes());
  }

  static Future<Uint8List> _dhWithPriv(
    Uint8List privateBytes,
    Uint8List remotePublic,
  ) async {
    final pair = await _x25519.newKeyPairFromSeed(privateBytes);
    return _dhWithPair(pair, remotePublic);
  }

  static Future<Uint8List> _encryptWithMk(
    Uint8List mk,
    Uint8List plaintext,
    Uint8List ad,
  ) async {
    final (key, nonce) = await E2eeKdf.expandMessageKey(mk);
    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: nonce,
      aad: ad,
    );
    return Uint8List.fromList(<int>[
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);
  }

  static Future<Uint8List> _decryptWithMk(
    Uint8List mk,
    Uint8List blob,
    Uint8List ad,
  ) async {
    final (key, _) = await E2eeKdf.expandMessageKey(mk);
    // Wire blob: nonce(12) || ciphertext || tag(16). Prefer embedded nonce.
    if (blob.length < 12 + 16) {
      throw StateError('Ciphertext too short');
    }
    final nonce = blob.sublist(0, 12);
    final mac = Mac(blob.sublist(blob.length - 16));
    final ct = blob.sublist(12, blob.length - 16);
    final clear = await _aesGcm.decrypt(
      SecretBox(ct, nonce: nonce, mac: mac),
      secretKey: SecretKey(key),
      aad: ad,
    );
    return Uint8List.fromList(clear);
  }

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

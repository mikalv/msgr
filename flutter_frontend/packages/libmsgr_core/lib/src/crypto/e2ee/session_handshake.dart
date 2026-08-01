import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'kdf.dart';
import 'types.dart';

/// XX-style (and optional prekey) session handshake.
///
/// No API requires the peer identity key as a precondition to *start* a session.
class SessionHandshake {
  SessionHandshake._();

  static final X25519 _x25519 = X25519();

  /// Start XX offer: generate ephemeral; caller sends IK+EK without knowing peer keys.
  static Future<XxInitOffer> initiateXx({
    required SimpleKeyPair identityKeyPair,
  }) async {
    final ikPub = await identityKeyPair.extractPublicKey();
    final ekPair = await _x25519.newKeyPair();
    final ekPub = await ekPair.extractPublicKey();
    final ekPriv = await ekPair.extractPrivateKeyBytes();
    final ikBytes = Uint8List.fromList(ikPub.bytes);
    final ekBytes = Uint8List.fromList(ekPub.bytes);
    return XxInitOffer(
      identityPublic: ikBytes,
      ephemeralPublic: ekBytes,
      ephemeralPrivate: Uint8List.fromList(ekPriv),
      header: RatchetHeader(dh: ekBytes, pn: 0, n: 0),
    );
  }

  /// Bob completes XX from Alice's init (remote IK/EK). Returns shared secret +
  /// Bob's ephemeral material for `init_ack`.
  static Future<SharedSecretResult> completeXx({
    required SimpleKeyPair identityKeyPair,
    required Uint8List remoteIdentityPublic,
    required Uint8List remoteEphemeralPublic,
  }) async {
    final localIkPub = await identityKeyPair.extractPublicKey();
    final ekPair = await _x25519.newKeyPair();
    final ekPub = await ekPair.extractPublicKey();
    final ekPriv = await ekPair.extractPrivateKeyBytes();

    final sk = await _deriveXx(
      identityKeyPair: identityKeyPair,
      localEphemeral: ekPair,
      remoteIdentityPublic: remoteIdentityPublic,
      remoteEphemeralPublic: remoteEphemeralPublic,
      localIsInitiator: false,
    );

    return SharedSecretResult(
      sharedSecret: sk,
      localIdentityPublic: Uint8List.fromList(localIkPub.bytes),
      remoteIdentityPublic: remoteIdentityPublic,
      remoteEphemeralPublic: remoteEphemeralPublic,
      localEphemeralPublic: Uint8List.fromList(ekPub.bytes),
      localEphemeralPrivate: Uint8List.fromList(ekPriv),
      isInitiator: false,
    );
  }

  /// Alice finishes XX after receiving Bob's `init_ack`.
  static Future<SharedSecretResult> finishXx({
    required SimpleKeyPair identityKeyPair,
    required Uint8List localEphemeralPrivate,
    required Uint8List localEphemeralPublic,
    required Uint8List remoteIdentityPublic,
    required Uint8List remoteEphemeralPublic,
  }) async {
    final localIkPub = await identityKeyPair.extractPublicKey();
    final localEk = await _x25519.newKeyPairFromSeed(localEphemeralPrivate);

    final sk = await _deriveXx(
      identityKeyPair: identityKeyPair,
      localEphemeral: localEk,
      remoteIdentityPublic: remoteIdentityPublic,
      remoteEphemeralPublic: remoteEphemeralPublic,
      localIsInitiator: true,
    );

    return SharedSecretResult(
      sharedSecret: sk,
      localIdentityPublic: Uint8List.fromList(localIkPub.bytes),
      remoteIdentityPublic: remoteIdentityPublic,
      remoteEphemeralPublic: remoteEphemeralPublic,
      localEphemeralPublic: localEphemeralPublic,
      localEphemeralPrivate: localEphemeralPrivate,
      isInitiator: true,
    );
  }

  /// Optional async prekey path when a bundle was discovered at send-time.
  static Future<SharedSecretResult> initiatePrekey({
    required SimpleKeyPair identityKeyPair,
    required PrekeyBundle bundle,
  }) async {
    final localIkPub = await identityKeyPair.extractPublicKey();
    final ekPair = await _x25519.newKeyPair();
    final ekPub = await ekPair.extractPublicKey();
    final ekPriv = await ekPair.extractPrivateKeyBytes();

    final dh1 = await _dh(
      identityKeyPair,
      bundle.signedPrekey,
    );
    final dh2 = await _dh(ekPair, bundle.identityKey);
    final dh3 = await _dh(ekPair, bundle.signedPrekey);
    final parts = <int>[...dh1, ...dh2, ...dh3];
    if (bundle.oneTimePrekey != null) {
      parts.addAll(await _dh(ekPair, bundle.oneTimePrekey!));
    }

    final sk = await E2eeKdf.deriveX3dhSharedSecret(Uint8List.fromList(parts));

    return SharedSecretResult(
      sharedSecret: sk,
      localIdentityPublic: Uint8List.fromList(localIkPub.bytes),
      remoteIdentityPublic: bundle.identityKey,
      remoteEphemeralPublic: bundle.signedPrekey,
      localEphemeralPublic: Uint8List.fromList(ekPub.bytes),
      localEphemeralPrivate: Uint8List.fromList(ekPriv),
      isInitiator: true,
    );
  }

  /// Deterministic concurrent-init tie-break: lowest sid is initiator.
  static bool shouldActAsInitiator(String localSid, String remoteSid) {
    return localSid.compareTo(remoteSid) < 0;
  }

  static Future<Uint8List> _deriveXx({
    required SimpleKeyPair identityKeyPair,
    required SimpleKeyPair localEphemeral,
    required Uint8List remoteIdentityPublic,
    required Uint8List remoteEphemeralPublic,
    required bool localIsInitiator,
  }) async {
    // SK = HKDF(DH(EK_a, IK_b) || DH(IK_a, EK_b) || DH(EK_a, EK_b))
    // Alice initiator: EK_a=localEph, IK_a=localIk, IK_b=remoteIk, EK_b=remoteEph
    // Bob responder:   EK_a=remoteEph, IK_a=remoteIk, IK_b=localIk, EK_b=localEph
    final Uint8List dh1;
    final Uint8List dh2;
    final Uint8List dh3;

    if (localIsInitiator) {
      dh1 = await _dh(localEphemeral, remoteIdentityPublic);
      dh2 = await _dh(identityKeyPair, remoteEphemeralPublic);
      dh3 = await _dh(localEphemeral, remoteEphemeralPublic);
    } else {
      dh1 = await _dh(identityKeyPair, remoteEphemeralPublic);
      dh2 = await _dh(localEphemeral, remoteIdentityPublic);
      dh3 = await _dh(localEphemeral, remoteEphemeralPublic);
    }

    return E2eeKdf.deriveXxSharedSecret(
      Uint8List.fromList(<int>[...dh1, ...dh2, ...dh3]),
    );
  }

  static Future<Uint8List> _dh(
    SimpleKeyPair privateKey,
    Uint8List remotePublic,
  ) async {
    final product = await _x25519.sharedSecretKey(
      keyPair: privateKey,
      remotePublicKey: SimplePublicKey(remotePublic, type: KeyPairType.x25519),
    );
    final data = await product.extractBytes();
    return Uint8List.fromList(data);
  }
}

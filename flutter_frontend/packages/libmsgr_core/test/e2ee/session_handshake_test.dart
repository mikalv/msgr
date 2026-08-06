import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:libmsgr_core/libmsgr_core.dart';
import 'package:test/test.dart';

void main() {
  final x25519 = X25519();

  test('XX handshake agrees without prior peer keys', () async {
    final aliceIk = await x25519.newKeyPair();
    final bobIk = await x25519.newKeyPair();

    final offer = await SessionHandshake.initiateXx(identityKeyPair: aliceIk);
    // Bob has only the offer bytes — no prior Alice key store required beyond the message.
    final bobComplete = await SessionHandshake.completeXx(
      identityKeyPair: bobIk,
      remoteIdentityPublic: offer.identityPublic,
      remoteEphemeralPublic: offer.ephemeralPublic,
    );
    final aliceFinish = await SessionHandshake.finishXx(
      identityKeyPair: aliceIk,
      localEphemeralPrivate: offer.ephemeralPrivate,
      localEphemeralPublic: offer.ephemeralPublic,
      remoteIdentityPublic: bobComplete.localIdentityPublic,
      remoteEphemeralPublic: bobComplete.localEphemeralPublic,
    );

    expect(aliceFinish.sharedSecret, equals(bobComplete.sharedSecret));
    expect(aliceFinish.isInitiator, isTrue);
    expect(bobComplete.isInitiator, isFalse);
  });

  test('concurrent init tie-break uses lowest sid', () {
    expect(
      SessionHandshake.shouldActAsInitiator('aaa', 'bbb'),
      isTrue,
    );
    expect(
      SessionHandshake.shouldActAsInitiator('zzz', 'aaa'),
      isFalse,
    );
  });

  test('optional prekey path produces 32-byte secret', () async {
    final aliceIk = await x25519.newKeyPair();
    final bobIk = await x25519.newKeyPair();
    final bobSpk = await x25519.newKeyPair();
    final bobIkPub = await bobIk.extractPublicKey();
    final bobSpkPub = await bobSpk.extractPublicKey();

    final result = await SessionHandshake.initiatePrekey(
      identityKeyPair: aliceIk,
      bundle: PrekeyBundle(
        deviceId: 'bob-1',
        identityKey: Uint8List.fromList(bobIkPub.bytes),
        signedPrekey: Uint8List.fromList(bobSpkPub.bytes),
        signedPrekeyId: 1,
        signedPrekeySignature: Uint8List(64),
      ),
    );
    expect(result.sharedSecret.length, 32);
    expect(result.isInitiator, isTrue);
  });
}

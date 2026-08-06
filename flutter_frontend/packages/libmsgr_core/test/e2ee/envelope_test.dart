import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:libmsgr_core/libmsgr_core.dart';
import 'package:test/test.dart';

Future<(RatchetSession, RatchetSession)> _pair() async {
  final x25519 = X25519();
  final aliceIk = await x25519.newKeyPair();
  final bobIk = await x25519.newKeyPair();
  final offer = await SessionHandshake.initiateXx(identityKeyPair: aliceIk);
  final bob = await SessionHandshake.completeXx(
    identityKeyPair: bobIk,
    remoteIdentityPublic: offer.identityPublic,
    remoteEphemeralPublic: offer.ephemeralPublic,
  );
  final alice = await SessionHandshake.finishXx(
    identityKeyPair: aliceIk,
    localEphemeralPrivate: offer.ephemeralPrivate,
    localEphemeralPublic: offer.ephemeralPublic,
    remoteIdentityPublic: bob.localIdentityPublic,
    remoteEphemeralPublic: bob.localEphemeralPublic,
  );
  return (
    await RatchetSession.initiatorFromSharedSecret(
      sharedSecret: alice.sharedSecret,
      localIdentityPublic: alice.localIdentityPublic,
      remoteIdentityPublic: alice.remoteIdentityPublic,
      remoteEphemeralPublic: alice.remoteEphemeralPublic,
    ),
    await RatchetSession.responderFromSharedSecret(
      sharedSecret: bob.sharedSecret,
      localIdentityPublic: bob.localIdentityPublic,
      remoteIdentityPublic: bob.remoteIdentityPublic,
      localEphemeralPrivate: bob.localEphemeralPrivate,
      localEphemeralPublic: bob.localEphemeralPublic,
    ),
  );
}

void main() {
  final codec = E2eeEnvelopeCodec();

  test('init envelope has no body', () {
    final built = codec.buildInit(
      senderDeviceId: 'alice-1',
      identityPublic: Uint8List(32),
      ephemeralPublic: Uint8List(32),
    );
    expect(built.envelope.ivCt, isNull);
    expect(built.envelope.keys.single.type, E2eeKeyType.init);
    expect(built.envelope.keys.single.rid, '*');
    expect(built.payload['e2ee']['iv_ct'], isNull);
  });

  test('message envelope wraps to peer and self devices', () async {
    final (aliceToBob, bobFromAlice) = await _pair();
    // Second pair simulates alice's other device session with alice-1 (self sync).
    // For the test we wrap only to bob; self-wrap uses another session target.
    final (aliceToSelf, selfFromAlice) = await _pair();

    final built = await codec.buildMessage(
      senderDeviceId: 'alice-1',
      plaintext: 'hemmelig',
      targets: [
        DeviceSessionTarget(deviceId: 'bob-1', session: aliceToBob),
        DeviceSessionTarget(deviceId: 'alice-2', session: aliceToSelf),
      ],
    );

    expect(built.envelope.ivCt, isNotNull);
    expect(built.envelope.keys.length, 2);

    final parsed = E2eeEnvelopeCodec.parse(built.payload);
    final forBob = await codec.decryptMessage(
      envelope: parsed,
      localDeviceId: 'bob-1',
      session: bobFromAlice,
    );
    expect(forBob, 'hemmelig');

    final forSelf = await codec.decryptMessage(
      envelope: parsed,
      localDeviceId: 'alice-2',
      session: selfFromAlice,
    );
    expect(forSelf, 'hemmelig');
  });

  test('wire JSON round-trip', () {
    final built = codec.buildInitAck(
      senderDeviceId: 'bob-1',
      recipientDeviceId: 'alice-1',
      identityPublic: Uint8List.fromList(List<int>.generate(32, (i) => i)),
      ephemeralPublic: Uint8List.fromList(List<int>.generate(32, (i) => 32 + i)),
    );
    final encoded = jsonEncode(built.payload);
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    final parsed = E2eeEnvelopeCodec.parse(decoded);
    expect(parsed.senderDeviceId, 'bob-1');
    expect(parsed.keys.single.type, E2eeKeyType.initAck);
    expect(parsed.keys.single.rid, 'alice-1');
  });
}

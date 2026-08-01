import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:libmsgr_core/libmsgr_core.dart';
import 'package:test/test.dart';

Future<(RatchetSession, RatchetSession)> _pairedSessions() async {
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

  final aliceSession = await RatchetSession.initiatorFromSharedSecret(
    sharedSecret: alice.sharedSecret,
    localIdentityPublic: alice.localIdentityPublic,
    remoteIdentityPublic: alice.remoteIdentityPublic,
    remoteEphemeralPublic: alice.remoteEphemeralPublic,
  );
  final bobSession = await RatchetSession.responderFromSharedSecret(
    sharedSecret: bob.sharedSecret,
    localIdentityPublic: bob.localIdentityPublic,
    remoteIdentityPublic: bob.remoteIdentityPublic,
    localEphemeralPrivate: bob.localEphemeralPrivate,
    localEphemeralPublic: bob.localEphemeralPublic,
  );
  return (aliceSession, bobSession);
}

void main() {
  test('round-trip encrypt/decrypt after XX', () async {
    final (alice, bob) = await _pairedSessions();
    final msg = await alice.encrypt(Uint8List.fromList(utf8.encode('hei')));
    final clear = await bob.decrypt(msg);
    expect(utf8.decode(clear), 'hei');
  });

  test('bidirectional messages with DH rotation', () async {
    final (alice, bob) = await _pairedSessions();
    for (var i = 0; i < 50; i++) {
      final aMsg = await alice.encrypt(Uint8List.fromList(utf8.encode('a$i')));
      expect(utf8.decode(await bob.decrypt(aMsg)), 'a$i');
      final bMsg = await bob.encrypt(Uint8List.fromList(utf8.encode('b$i')));
      expect(utf8.decode(await alice.decrypt(bMsg)), 'b$i');
    }
  });

  test('out-of-order delivery via skipped keys', () async {
    final (alice, bob) = await _pairedSessions();
    final m0 = await alice.encrypt(Uint8List.fromList(utf8.encode('0')));
    final m1 = await alice.encrypt(Uint8List.fromList(utf8.encode('1')));
    final m2 = await alice.encrypt(Uint8List.fromList(utf8.encode('2')));

    expect(utf8.decode(await bob.decrypt(m2)), '2');
    expect(utf8.decode(await bob.decrypt(m0)), '0');
    expect(utf8.decode(await bob.decrypt(m1)), '1');
  });

  test('session survives JSON serialization', () async {
    final (alice, bob) = await _pairedSessions();
    final msg = await alice.encrypt(Uint8List.fromList(utf8.encode('persist')));
    final restored = RatchetSession.fromJson(bob.toJson());
    expect(utf8.decode(await restored.decrypt(msg)), 'persist');
  });

  test('200+ messages across rotations', () async {
    final (alice, bob) = await _pairedSessions();
    for (var i = 0; i < 220; i++) {
      if (i.isEven) {
        final msg =
            await alice.encrypt(Uint8List.fromList(utf8.encode('x$i')));
        expect(utf8.decode(await bob.decrypt(msg)), 'x$i');
      } else {
        final msg = await bob.encrypt(Uint8List.fromList(utf8.encode('y$i')));
        expect(utf8.decode(await alice.decrypt(msg)), 'y$i');
      }
    }
  });
}

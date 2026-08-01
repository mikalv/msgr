import 'package:libmsgr_core/libmsgr_core.dart';
import 'package:test/test.dart';

Future<E2eeService> _service() async {
  final storage = MemorySecureStorage();
  final keys = KeyManager(storage: storage);
  await keys.getOrGenerateDeviceId();
  return E2eeService(keyManager: keys, store: MemoryE2eeSessionStore());
}

void main() {
  test('XX 1:1 without prior peer keys, then plaintext after ack', () async {
    final alice = await _service();
    final bob = await _service();

    final init = await alice.prepareSend(
      peerProfileId: 'profile-bob',
      plaintext: 'hei bob',
    );
    expect(init.queued, isTrue);
    expect(init.payload['e2ee']['iv_ct'], isNull);

    final bobSeesInit = await bob.handleIncoming(
      peerProfileId: 'profile-alice',
      payload: init.payload,
    );
    expect(bobSeesInit.ackPayload, isNotNull);

    await alice.handleIncoming(
      peerProfileId: 'profile-bob',
      payload: bobSeesInit.ackPayload!,
    );

    final flushed = await alice.flushPending(peerProfileId: 'profile-bob');
    expect(flushed, hasLength(1));
    expect(flushed.single.payload['e2ee']['iv_ct'], isNotNull);

    final bobReads = await bob.handleIncoming(
      peerProfileId: 'profile-alice',
      payload: flushed.single.payload,
    );
    expect(bobReads.plaintext, 'hei bob');
  });

  test('bidirectional messages after session', () async {
    final alice = await _service();
    final bob = await _service();

    final init =
        await alice.prepareSend(peerProfileId: 'b', plaintext: '1');
    final ack = (await bob.handleIncoming(
      peerProfileId: 'a',
      payload: init.payload,
    ))
        .ackPayload!;
    await alice.handleIncoming(peerProfileId: 'b', payload: ack);
    final first = await alice.flushPending(peerProfileId: 'b');
    expect(
      (await bob.handleIncoming(
        peerProfileId: 'a',
        payload: first.single.payload,
      ))
          .plaintext,
      '1',
    );

    final bobReply =
        await bob.prepareSend(peerProfileId: 'a', plaintext: '2');
    expect(
      (await alice.handleIncoming(
        peerProfileId: 'b',
        payload: bobReply.payload,
      ))
          .plaintext,
      '2',
    );
  });

  test('envelope never contains plaintext', () async {
    final alice = await _service();
    final bob = await _service();
    final init =
        await alice.prepareSend(peerProfileId: 'b', plaintext: 'secret');
    final ack = (await bob.handleIncoming(
      peerProfileId: 'a',
      payload: init.payload,
    ))
        .ackPayload!;
    await alice.handleIncoming(peerProfileId: 'b', payload: ack);
    final msg = (await alice.flushPending(peerProfileId: 'b')).single.payload;
    expect(msg.toString().contains('secret'), isFalse);
  });
}

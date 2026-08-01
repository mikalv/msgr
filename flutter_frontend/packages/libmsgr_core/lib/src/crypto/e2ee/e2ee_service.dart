import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:logging/logging.dart';

import '../../crypto/key_manager.dart';
import 'double_ratchet.dart';
import 'envelope.dart';
import 'session_handshake.dart';
import 'session_store.dart';
import 'types.dart';

class E2eeSendResult {
  const E2eeSendResult({
    required this.kind,
    required this.payload,
    this.queued = false,
    this.displayBody = '',
  });

  /// Wire message kind (`encrypted`).
  final String kind;
  final Map<String, dynamic> payload;

  /// True when only `init` was sent and plaintext is queued locally.
  final bool queued;
  final String displayBody;
}

class E2eeReceiveResult {
  const E2eeReceiveResult({
    this.plaintext,
    this.ackPayload,
    this.connecting = false,
    this.undecryptable = false,
  });

  final String? plaintext;

  /// Optional `init_ack` envelope the caller should send back.
  final Map<String, dynamic>? ackPayload;
  final bool connecting;
  final bool undecryptable;
}

/// Personal-mode 1:1 E2EE orchestration (docs/e2ee_spec.md).
class E2eeService {
  E2eeService({
    required KeyManager keyManager,
    required E2eeSessionStore store,
    E2eeEnvelopeCodec? codec,
    Logger? log,
  })  : _keyManager = keyManager,
        _store = store,
        _codec = codec ?? E2eeEnvelopeCodec(),
        _log = log ?? Logger('E2eeService');

  final KeyManager _keyManager;
  final E2eeSessionStore _store;
  final E2eeEnvelopeCodec _codec;
  final Logger _log;
  final Map<String, RatchetSession> _sessions = {};
  final Map<String, List<String>> _pendingPlaintext = {};
  final Map<String, Uint8List> _pendingEkPrivate = {};

  String get deviceId => _keyManager.deviceId;

  Future<void> ensureReady() async {
    if (_keyManager.isLoading) {
      await _keyManager.getOrGenerateDeviceId();
    }
    final ikPriv = await _keyManager.dhKeyPair.extractPrivateKeyBytes();
    final ikPub = await _keyManager.dhKeyPair.extractPublicKey();
    await _store.upsertOwnDevice(
      deviceId: deviceId,
      identityPrivate: base64Encode(ikPriv),
      identityPublic: base64Encode(ikPub.bytes),
    );
  }

  /// Prepare outbound send. Without a session, queues plaintext and returns init-only.
  Future<E2eeSendResult> prepareSend({
    required String peerProfileId,
    required String plaintext,
    List<String> selfOtherDeviceIds = const [],
    List<String> peerDeviceIds = const [],
  }) async {
    await ensureReady();
    final existing = await _loadSessions(peerProfileId);
    if (existing.isEmpty) {
      final offer = await SessionHandshake.initiateXx(
        identityKeyPair: _keyManager.dhKeyPair,
      );
      final key = _pendingKey(peerProfileId, '*');
      _pendingEkPrivate[key] = offer.ephemeralPrivate;
      _pendingPlaintext.putIfAbsent(peerProfileId, () => <String>[]).add(plaintext);
      await _store.upsertRatchet(
        peerProfileId: peerProfileId,
        peerDeviceId: '*',
        sessionJson: const {},
        pendingEkPrivate: base64Encode(offer.ephemeralPrivate),
        pendingPlaintexts: _pendingPlaintext[peerProfileId],
      );
      final built = _codec.buildInit(
        senderDeviceId: deviceId,
        identityPublic: offer.identityPublic,
        ephemeralPublic: offer.ephemeralPublic,
      );
      return E2eeSendResult(
        kind: 'encrypted',
        payload: built.payload,
        queued: true,
        displayBody: plaintext,
      );
    }

    final targets = <DeviceSessionTarget>[];
    for (final entry in existing.entries) {
      targets.add(DeviceSessionTarget(deviceId: entry.key, session: entry.value));
    }
    for (final selfId in selfOtherDeviceIds) {
      final selfSession = _sessions[_sessionKey(peerProfileId: deviceId, peerDeviceId: selfId)];
      if (selfSession != null) {
        targets.add(DeviceSessionTarget(deviceId: selfId, session: selfSession));
      }
    }

    final built = await _codec.buildMessage(
      senderDeviceId: deviceId,
      plaintext: plaintext,
      targets: targets,
    );
    await _persistAll(peerProfileId, existing);
    return E2eeSendResult(
      kind: 'encrypted',
      payload: built.payload,
      displayBody: plaintext,
    );
  }

  /// Handle inbound envelope. May produce plaintext and/or an init_ack to send.
  Future<E2eeReceiveResult> handleIncoming({
    required String peerProfileId,
    required Map<String, dynamic> payload,
  }) async {
    await ensureReady();
    final envelope = E2eeEnvelopeCodec.parse(payload);
    final entry = envelope.entryFor(deviceId);
    if (entry == null) {
      return const E2eeReceiveResult(undecryptable: true);
    }

    switch (entry.type) {
      case E2eeKeyType.init:
        return _handleInit(
          peerProfileId: peerProfileId,
          senderDeviceId: envelope.senderDeviceId,
          entry: entry,
        );
      case E2eeKeyType.initAck:
        return _handleInitAck(
          peerProfileId: peerProfileId,
          senderDeviceId: envelope.senderDeviceId,
          entry: entry,
        );
      case E2eeKeyType.msg:
      case E2eeKeyType.prekey:
        return _handleMsg(
          peerProfileId: peerProfileId,
          senderDeviceId: envelope.senderDeviceId,
          envelope: envelope,
        );
    }
  }

  /// After init_ack establishes sessions, flush queued plaintexts as msg envelopes.
  Future<List<E2eeSendResult>> flushPending({
    required String peerProfileId,
    List<String> selfOtherDeviceIds = const [],
  }) async {
    final queued = List<String>.from(_pendingPlaintext[peerProfileId] ?? const []);
    if (queued.isEmpty) return const [];
    _pendingPlaintext.remove(peerProfileId);
    final out = <E2eeSendResult>[];
    for (final text in queued) {
      out.add(
        await prepareSend(
          peerProfileId: peerProfileId,
          plaintext: text,
          selfOtherDeviceIds: selfOtherDeviceIds,
        ),
      );
    }
    return out;
  }

  Future<E2eeReceiveResult> _handleInit({
    required String peerProfileId,
    required String senderDeviceId,
    required EnvelopeKeyEntry entry,
  }) async {
    if (entry.ik == null || entry.ek == null) {
      return const E2eeReceiveResult(undecryptable: true);
    }

    // Concurrent init tie-break
    if (!SessionHandshake.shouldActAsInitiator(deviceId, senderDeviceId)) {
      // We are higher sid — abandon our pending init and ack theirs.
      _pendingEkPrivate.remove(_pendingKey(peerProfileId, '*'));
    } else if (_pendingEkPrivate.containsKey(_pendingKey(peerProfileId, '*'))) {
      // We are initiator; ignore concurrent init from higher sid.
      return const E2eeReceiveResult(connecting: true);
    }

    final complete = await SessionHandshake.completeXx(
      identityKeyPair: _keyManager.dhKeyPair,
      remoteIdentityPublic: entry.ik!,
      remoteEphemeralPublic: entry.ek!,
    );
    final session = await RatchetSession.responderFromSharedSecret(
      sharedSecret: complete.sharedSecret,
      localIdentityPublic: complete.localIdentityPublic,
      remoteIdentityPublic: complete.remoteIdentityPublic,
      localEphemeralPrivate: complete.localEphemeralPrivate,
      localEphemeralPublic: complete.localEphemeralPublic,
    );
    _sessions[_sessionKey(peerProfileId: peerProfileId, peerDeviceId: senderDeviceId)] =
        session;
    await _store.upsertRatchet(
      peerProfileId: peerProfileId,
      peerDeviceId: senderDeviceId,
      sessionJson: session.toJson(),
    );
    await _tofu(senderDeviceId, entry.ik!);
    await _store.upsertDeviceList(peerProfileId, [senderDeviceId]);

    final ack = _codec.buildInitAck(
      senderDeviceId: deviceId,
      recipientDeviceId: senderDeviceId,
      identityPublic: complete.localIdentityPublic,
      ephemeralPublic: complete.localEphemeralPublic,
    );
    return E2eeReceiveResult(ackPayload: ack.payload, connecting: true);
  }

  Future<E2eeReceiveResult> _handleInitAck({
    required String peerProfileId,
    required String senderDeviceId,
    required EnvelopeKeyEntry entry,
  }) async {
    if (entry.ik == null || entry.ek == null) {
      return const E2eeReceiveResult(undecryptable: true);
    }
    final pendingKey = _pendingKey(peerProfileId, '*');
    var ekPriv = _pendingEkPrivate.remove(pendingKey);
    if (ekPriv == null) {
      final row = await _store.getRatchetRow(peerProfileId, '*');
      final stored = row?['pending_ek_private'] as String?;
      if (stored != null) {
        ekPriv = Uint8List.fromList(base64Decode(stored));
      }
    }
    if (ekPriv == null) {
      _log.warning('init_ack without pending XX ephemeral');
      return const E2eeReceiveResult(undecryptable: true);
    }

    final offerPub = await X25519().newKeyPairFromSeed(ekPriv);
    final offerPubBytes =
        Uint8List.fromList((await offerPub.extractPublicKey()).bytes);

    final finish = await SessionHandshake.finishXx(
      identityKeyPair: _keyManager.dhKeyPair,
      localEphemeralPrivate: ekPriv,
      localEphemeralPublic: offerPubBytes,
      remoteIdentityPublic: entry.ik!,
      remoteEphemeralPublic: entry.ek!,
    );
    final session = await RatchetSession.initiatorFromSharedSecret(
      sharedSecret: finish.sharedSecret,
      localIdentityPublic: finish.localIdentityPublic,
      remoteIdentityPublic: finish.remoteIdentityPublic,
      remoteEphemeralPublic: finish.remoteEphemeralPublic,
    );
    _sessions[_sessionKey(peerProfileId: peerProfileId, peerDeviceId: senderDeviceId)] =
        session;
    await _store.upsertRatchet(
      peerProfileId: peerProfileId,
      peerDeviceId: senderDeviceId,
      sessionJson: session.toJson(),
      pendingPlaintexts: _pendingPlaintext[peerProfileId],
    );
    await _tofu(senderDeviceId, entry.ik!);
    await _store.upsertDeviceList(peerProfileId, [senderDeviceId]);
    return const E2eeReceiveResult(connecting: false);
  }

  Future<E2eeReceiveResult> _handleMsg({
    required String peerProfileId,
    required String senderDeviceId,
    required E2eeEnvelope envelope,
  }) async {
    final key = _sessionKey(peerProfileId: peerProfileId, peerDeviceId: senderDeviceId);
    var session = _sessions[key];
    if (session == null) {
      final row = await _store.getRatchetRow(peerProfileId, senderDeviceId);
      final parsed = _parseSessionJson(row?['session_json']);
      if (parsed == null) {
        return const E2eeReceiveResult(undecryptable: true);
      }
      session = RatchetSession.fromJson(parsed);
      _sessions[key] = session;
    }
    try {
      final plaintext = await _codec.decryptMessage(
        envelope: envelope,
        localDeviceId: deviceId,
        session: session,
      );
      await _store.upsertRatchet(
        peerProfileId: peerProfileId,
        peerDeviceId: senderDeviceId,
        sessionJson: session.toJson(),
      );
      return E2eeReceiveResult(plaintext: plaintext);
    } catch (error, stack) {
      _log.warning('decrypt failed: $error\n$stack');
      return const E2eeReceiveResult(undecryptable: true);
    }
  }

  Future<Map<String, RatchetSession>> _loadSessions(String peerProfileId) async {
    final rows = await _store.getRatchetsForProfile(peerProfileId);
    final out = <String, RatchetSession>{};
    for (final row in rows) {
      final deviceId = row['peer_device_id'] as String;
      if (deviceId == '*') continue;
      final parsed = _parseSessionJson(row['session_json']);
      if (parsed == null) continue;
      final session = RatchetSession.fromJson(parsed);
      final key = _sessionKey(peerProfileId: peerProfileId, peerDeviceId: deviceId);
      _sessions[key] = session;
      out[deviceId] = session;
    }
    return out;
  }

  Future<void> _persistAll(
    String peerProfileId,
    Map<String, RatchetSession> sessions,
  ) async {
    for (final entry in sessions.entries) {
      await _store.upsertRatchet(
        peerProfileId: peerProfileId,
        peerDeviceId: entry.key,
        sessionJson: entry.value.toJson(),
      );
    }
  }

  Future<void> _tofu(String peerDeviceId, Uint8List identityPublic) async {
    final existing = await _store.getTrust(peerDeviceId);
    if (existing != null) return;
    final fingerprint = base64Encode(identityPublic);
    await _store.upsertTrust(
      deviceId: peerDeviceId,
      fingerprint: fingerprint,
      trustLevel: 'tofu',
    );
  }

  Map<String, dynamic>? _parseSessionJson(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      if (raw.isEmpty) return null;
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String) {
      if (raw.isEmpty || raw == '{}') return null;
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    }
    return null;
  }

  static String _sessionKey({
    required String peerProfileId,
    required String peerDeviceId,
  }) =>
      '$peerProfileId::$peerDeviceId';

  static String _pendingKey(String peerProfileId, String peerDeviceId) =>
      _sessionKey(peerProfileId: peerProfileId, peerDeviceId: peerDeviceId);
}

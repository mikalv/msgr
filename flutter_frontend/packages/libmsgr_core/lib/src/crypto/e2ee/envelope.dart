import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'double_ratchet.dart';
import 'types.dart';

class DeviceSessionTarget {
  const DeviceSessionTarget({
    required this.deviceId,
    required this.session,
  });

  final String deviceId;
  final RatchetSession session;
}

class BuiltEnvelope {
  const BuiltEnvelope({
    required this.envelope,
    required this.payload,
  });

  final E2eeEnvelope envelope;

  /// Full message payload map ready for the wire (`payload` field).
  final Map<String, dynamic> payload;
}

/// Build / parse E2EE envelopes and encrypt plaintext with a random payload key.
class E2eeEnvelopeCodec {
  E2eeEnvelopeCodec({Random? random}) : _random = random ?? Random.secure();

  final Random _random;
  static final AesGcm _aesGcm = AesGcm.with256bits();

  /// Handshake-only init (no body).
  BuiltEnvelope buildInit({
    required String senderDeviceId,
    required Uint8List identityPublic,
    required Uint8List ephemeralPublic,
  }) {
    final envelope = E2eeEnvelope(
      version: 1,
      senderDeviceId: senderDeviceId,
      ivCt: null,
      keys: <EnvelopeKeyEntry>[
        EnvelopeKeyEntry(
          rid: '*',
          type: E2eeKeyType.init,
          ik: identityPublic,
          ek: ephemeralPublic,
          header: RatchetHeader(dh: ephemeralPublic, pn: 0, n: 0),
          ct: null,
        ),
      ],
    );
    return BuiltEnvelope(envelope: envelope, payload: envelope.toJson());
  }

  BuiltEnvelope buildInitAck({
    required String senderDeviceId,
    required String recipientDeviceId,
    required Uint8List identityPublic,
    required Uint8List ephemeralPublic,
  }) {
    final envelope = E2eeEnvelope(
      version: 1,
      senderDeviceId: senderDeviceId,
      ivCt: null,
      keys: <EnvelopeKeyEntry>[
        EnvelopeKeyEntry(
          rid: recipientDeviceId,
          type: E2eeKeyType.initAck,
          ik: identityPublic,
          ek: ephemeralPublic,
          header: RatchetHeader(dh: ephemeralPublic, pn: 0, n: 0),
          ct: null,
        ),
      ],
    );
    return BuiltEnvelope(envelope: envelope, payload: envelope.toJson());
  }

  /// Encrypt plaintext for peer devices + own other devices.
  Future<BuiltEnvelope> buildMessage({
    required String senderDeviceId,
    required String plaintext,
    required List<DeviceSessionTarget> targets,
  }) async {
    if (targets.isEmpty) {
      throw ArgumentError('At least one device target is required');
    }
    final payloadKey = _randomBytes(32);
    final ivCt = await _encryptPayload(payloadKey, utf8.encode(plaintext));

    final keys = <EnvelopeKeyEntry>[];
    for (final target in targets) {
      final ratchetMsg = await target.session.encrypt(payloadKey);
      keys.add(
        EnvelopeKeyEntry(
          rid: target.deviceId,
          type: E2eeKeyType.msg,
          header: ratchetMsg.header,
          ct: ratchetMsg.ciphertext,
        ),
      );
    }

    final envelope = E2eeEnvelope(
      version: 1,
      senderDeviceId: senderDeviceId,
      ivCt: ivCt,
      keys: keys,
    );
    return BuiltEnvelope(envelope: envelope, payload: envelope.toJson());
  }

  Future<String> decryptMessage({
    required E2eeEnvelope envelope,
    required String localDeviceId,
    required RatchetSession session,
  }) async {
    final entry = envelope.entryFor(localDeviceId);
    if (entry == null || entry.ct == null || envelope.ivCt == null) {
      throw StateError('No decryptable key entry for $localDeviceId');
    }
    if (entry.type != E2eeKeyType.msg && entry.type != E2eeKeyType.prekey) {
      throw StateError('Entry type ${entry.type.wire} is not a message');
    }
    final payloadKey = await session.decrypt(
      RatchetMessage(header: entry.header, ciphertext: entry.ct!),
    );
    final clear = await _decryptPayload(payloadKey, envelope.ivCt!);
    return utf8.decode(clear);
  }

  static E2eeEnvelope parse(Map<String, dynamic> payload) {
    return E2eeEnvelope.fromJson(payload);
  }

  Future<Uint8List> _encryptPayload(
    Uint8List payloadKey,
    List<int> plaintext,
  ) async {
    final nonce = _randomBytes(12);
    final box = await _aesGcm.encrypt(
      plaintext,
      secretKey: SecretKey(payloadKey),
      nonce: nonce,
    );
    return Uint8List.fromList(<int>[
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  Future<Uint8List> _decryptPayload(
    Uint8List payloadKey,
    Uint8List blob,
  ) async {
    if (blob.length < 12 + 16) {
      throw StateError('iv_ct too short');
    }
    final nonce = blob.sublist(0, 12);
    final mac = Mac(blob.sublist(blob.length - 16));
    final ct = blob.sublist(12, blob.length - 16);
    final clear = await _aesGcm.decrypt(
      SecretBox(ct, nonce: nonce, mac: mac),
      secretKey: SecretKey(payloadKey),
    );
    return Uint8List.fromList(clear);
  }

  Uint8List _randomBytes(int length) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = _random.nextInt(256);
    }
    return out;
  }
}

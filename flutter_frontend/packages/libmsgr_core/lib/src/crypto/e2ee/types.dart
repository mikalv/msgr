import 'dart:convert';
import 'dart:typed_data';

/// Wire / domain types for msgr E2EE (see docs/e2ee_spec.md).

enum E2eeKeyType {
  init,
  initAck,
  prekey,
  msg;

  String get wire {
    switch (this) {
      case E2eeKeyType.init:
        return 'init';
      case E2eeKeyType.initAck:
        return 'init_ack';
      case E2eeKeyType.prekey:
        return 'prekey';
      case E2eeKeyType.msg:
        return 'msg';
    }
  }

  static E2eeKeyType fromWire(String value) {
    switch (value) {
      case 'init':
        return E2eeKeyType.init;
      case 'init_ack':
        return E2eeKeyType.initAck;
      case 'prekey':
        return E2eeKeyType.prekey;
      case 'msg':
        return E2eeKeyType.msg;
      default:
        throw FormatException('Unknown e2ee key type: $value');
    }
  }
}

class RatchetHeader {
  const RatchetHeader({
    required this.dh,
    required this.pn,
    required this.n,
  });

  final Uint8List dh;
  final int pn;
  final int n;

  Uint8List encode() {
    final out = Uint8List(40);
    out.setAll(0, dh);
    final bd = ByteData.sublistView(out);
    bd.setUint32(32, pn, Endian.big);
    bd.setUint32(36, n, Endian.big);
    return out;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'dh': base64Encode(dh),
        'pn': pn,
        'n': n,
      };

  factory RatchetHeader.fromJson(Map<String, dynamic> json) {
    return RatchetHeader(
      dh: Uint8List.fromList(base64Decode(json['dh'] as String)),
      pn: json['pn'] as int,
      n: json['n'] as int,
    );
  }
}

class PrekeyBundle {
  const PrekeyBundle({
    required this.deviceId,
    required this.identityKey,
    required this.signedPrekey,
    required this.signedPrekeyId,
    required this.signedPrekeySignature,
    this.oneTimePrekey,
    this.oneTimePrekeyId,
  });

  final String deviceId;
  final Uint8List identityKey;
  final Uint8List signedPrekey;
  final int signedPrekeyId;
  final Uint8List signedPrekeySignature;
  final Uint8List? oneTimePrekey;
  final int? oneTimePrekeyId;
}

class EnvelopeKeyEntry {
  const EnvelopeKeyEntry({
    required this.rid,
    required this.type,
    this.ik,
    this.ek,
    this.spkId,
    this.opkId,
    required this.header,
    this.ct,
  });

  final String rid;
  final E2eeKeyType type;
  final Uint8List? ik;
  final Uint8List? ek;
  final int? spkId;
  final int? opkId;
  final RatchetHeader header;
  final Uint8List? ct;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'rid': rid,
        'type': type.wire,
        'ik': ik == null ? null : base64Encode(ik!),
        'ek': ek == null ? null : base64Encode(ek!),
        'spk_id': spkId,
        'opk_id': opkId,
        'header': header.toJson(),
        'ct': ct == null ? null : base64Encode(ct!),
      };

  factory EnvelopeKeyEntry.fromJson(Map<String, dynamic> json) {
    Uint8List? decodeOpt(dynamic value) {
      if (value == null) return null;
      return Uint8List.fromList(base64Decode(value as String));
    }

    return EnvelopeKeyEntry(
      rid: json['rid'] as String,
      type: E2eeKeyType.fromWire(json['type'] as String),
      ik: decodeOpt(json['ik']),
      ek: decodeOpt(json['ek']),
      spkId: json['spk_id'] as int?,
      opkId: json['opk_id'] as int?,
      header: RatchetHeader.fromJson(
        Map<String, dynamic>.from(json['header'] as Map),
      ),
      ct: decodeOpt(json['ct']),
    );
  }
}

class E2eeEnvelope {
  const E2eeEnvelope({
    required this.version,
    required this.senderDeviceId,
    this.ivCt,
    required this.keys,
  });

  final int version;
  final String senderDeviceId;
  final Uint8List? ivCt;
  final List<EnvelopeKeyEntry> keys;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': version,
        'e2ee': <String, dynamic>{
          'sid': senderDeviceId,
          'iv_ct': ivCt == null ? null : base64Encode(ivCt!),
          'keys': keys.map((k) => k.toJson()).toList(),
        },
      };

  factory E2eeEnvelope.fromJson(Map<String, dynamic> json) {
    final e2ee = Map<String, dynamic>.from(json['e2ee'] as Map);
    final iv = e2ee['iv_ct'];
    return E2eeEnvelope(
      version: json['v'] as int? ?? 1,
      senderDeviceId: e2ee['sid'] as String,
      ivCt: iv == null ? null : Uint8List.fromList(base64Decode(iv as String)),
      keys: (e2ee['keys'] as List)
          .map(
            (e) => EnvelopeKeyEntry.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }

  EnvelopeKeyEntry? entryFor(String localDeviceId) {
    for (final key in keys) {
      if (key.rid == localDeviceId) return key;
    }
    for (final key in keys) {
      if (key.rid == '*') return key;
    }
    return null;
  }
}

class XxInitOffer {
  const XxInitOffer({
    required this.identityPublic,
    required this.ephemeralPublic,
    required this.ephemeralPrivate,
    required this.header,
  });

  final Uint8List identityPublic;
  final Uint8List ephemeralPublic;
  final Uint8List ephemeralPrivate;
  final RatchetHeader header;
}

class SharedSecretResult {
  const SharedSecretResult({
    required this.sharedSecret,
    required this.localIdentityPublic,
    required this.remoteIdentityPublic,
    required this.remoteEphemeralPublic,
    required this.localEphemeralPublic,
    required this.localEphemeralPrivate,
    required this.isInitiator,
  });

  final Uint8List sharedSecret;
  final Uint8List localIdentityPublic;
  final Uint8List remoteIdentityPublic;
  final Uint8List remoteEphemeralPublic;
  final Uint8List localEphemeralPublic;
  final Uint8List localEphemeralPrivate;
  final bool isInitiator;
}

// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:cryptography/cryptography.dart';
import 'package:libmsgr/src/models/base.dart';
import 'package:meta/meta.dart';

@immutable
class Device extends BaseModel {
  final SimpleKeyPair signingKeyPair;
  final SimpleKeyPair dhKeyPair;

  String get deviceId => id;

  Device.raw({required this.signingKeyPair, required this.dhKeyPair, super.id});

  factory Device({signingKeyPair, dhKeyPair}) {
    return Device.raw(signingKeyPair: signingKeyPair, dhKeyPair: dhKeyPair);
  }

  Map<String, dynamic> toJson() {
    return {
      'signingKeyPair': {
        'publicKey': signingKeyPair.extractPublicKey(),
        'privateKey': signingKeyPair.extractPrivateKeyBytes(),
      },
      'dhKeyPair': {
        'publicKey': dhKeyPair.extractPublicKey(),
        'privateKey': dhKeyPair.extractPrivateKeyBytes(),
      },
      'deviceId': deviceId,
    };
  }

  static Future<Device> fromJson(Map<String, dynamic> json) async {
    final signAlgorithm = Ed25519();
    final dhAlgorithm = X25519();

    return Device.raw(
      signingKeyPair: await signAlgorithm
          .newKeyPairFromSeed(json['signingKeyPair']['privateKey']),
      dhKeyPair:
          await dhAlgorithm.newKeyPairFromSeed(json['dhKeyPair']['privateKey']),
      id: json['deviceId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'signingKeyPair': {
        'publicKey': signingKeyPair.extractPublicKey(),
        'privateKey': signingKeyPair.extractPrivateKeyBytes(),
      },
      'dhKeyPair': {
        'publicKey': dhKeyPair.extractPublicKey(),
        'privateKey': dhKeyPair.extractPrivateKeyBytes(),
      },
      'deviceId': deviceId,
    };
  }

  static Future<Device> fromMap(Map<String, dynamic> map) async {
    final signAlgorithm = Ed25519();
    final dhAlgorithm = X25519();

    return Device.raw(
      signingKeyPair: await signAlgorithm
          .newKeyPairFromSeed(map['signingKeyPair']['privateKey']),
      dhKeyPair:
          await dhAlgorithm.newKeyPairFromSeed(map['dhKeyPair']['privateKey']),
      id: map['deviceId'],
    );
  }

  Device copyWith({
    SimpleKeyPair? signingKeyPair,
    SimpleKeyPair? dhKeyPair,
    String? deviceId,
  }) {
    return Device.raw(
      signingKeyPair: signingKeyPair ?? this.signingKeyPair,
      dhKeyPair: dhKeyPair ?? this.dhKeyPair,
      id: deviceId ?? this.deviceId,
    );
  }
}

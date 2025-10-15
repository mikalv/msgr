import 'package:libmsgr_core/libmsgr_core.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  group('RegistrationServiceCore noise handshake', () {
    late InMemorySecureStorage storage;
    late KeyManager keyManager;
    late FakeDeviceInfoProvider deviceInfo;
    late RecordingRegistrationApi api;
    late RegistrationServiceCore service;

    setUp(() async {
      Logger.root.level = Level.WARNING;
      storage = InMemorySecureStorage();
      keyManager = KeyManager(storage: storage);
      deviceInfo = FakeDeviceInfoProvider();
      api = RecordingRegistrationApi();
      service = RegistrationServiceCore(
        keyManager: keyManager,
        secureStorage: storage,
        deviceInfoProvider: deviceInfo,
        api: api,
      );
    });

    test('requestChallenge sends Noise device key when handshake is available', () async {
      api.handshake = NoiseHandshakeSession(
        sessionId: 'session-1',
        signature: 'signature-1',
        deviceKey: 'noise-device',
        devicePrivateKey: 'private',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        server: const {},
      );

      final challenge = await service.requestChallenge(
        channel: 'email',
        identifier: 'noise@example.com',
      );

      expect(challenge, isNotNull);
      expect(api.requestedDeviceIds, contains('noise-device'));
      expect(api.handshakeCalls, equals(1));
    });

    test('verifyCode attaches handshake metadata for OTP flow', () async {
      api.handshake = NoiseHandshakeSession(
        sessionId: 'session-2',
        signature: 'signature-2',
        deviceKey: 'noise-device',
        devicePrivateKey: 'private',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        server: const {},
      );

      final challenge = await service.requestChallenge(
        channel: 'email',
        identifier: 'noise@example.com',
      );
      expect(challenge, isNotNull);

      final session = await service.verifyCode(
        challengeId: challenge!.id,
        code: '123456',
        displayName: 'Noise Tester',
      );

      expect(session, isNotNull);
      expect(api.lastVerifyPayload?['noise_session_id'], equals('session-2'));
      expect(api.lastVerifyPayload?['noise_signature'], equals('signature-2'));
      expect(api.lastVerifyPayload?['last_handshake_at'], isA<String>());
      expect(api.handshake, isNull);
    });
  });
}

class RecordingRegistrationApi extends RegistrationApi {
  NoiseHandshakeSession? handshake;
  int handshakeCalls = 0;
  final List<String> requestedDeviceIds = <String>[];
  Map<String, dynamic>? lastVerifyPayload;

  @override
  Future<NoiseHandshakeSession?> createNoiseHandshake() async {
    handshakeCalls += 1;
    return handshake;
  }

  @override
  Future<AuthChallenge?> requestChallenge({
    required String channel,
    required String identifier,
    required String deviceId,
  }) async {
    requestedDeviceIds.add(deviceId);
    return AuthChallenge(
      id: 'challenge-${requestedDeviceIds.length}',
      channel: channel,
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      targetHint: identifier,
      debugCode: '123456',
    );
  }

  @override
  Future<Map<String, dynamic>?> verifyCode({
    required String challengeId,
    required String code,
    String? displayName,
    String? noiseSessionId,
    String? noiseSignature,
    DateTime? lastHandshakeAt,
  }) async {
    lastVerifyPayload = <String, dynamic>{
      'challenge_id': challengeId,
      'code': code,
      if (displayName != null) 'display_name': displayName,
      if (noiseSessionId != null) 'noise_session_id': noiseSessionId,
      if (noiseSignature != null) 'noise_signature': noiseSignature,
      if (lastHandshakeAt != null)
        'last_handshake_at': lastHandshakeAt.toUtc().toIso8601String(),
    };
    handshake = null;
    return <String, dynamic>{
      'account': <String, dynamic>{'id': 'account-1', 'email': 'noise@example.com'},
      'identity': <String, dynamic>{'id': 'identity-1', 'kind': 'email'},
    };
  }
}

class InMemorySecureStorage implements SecureStorage {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<bool> containsKey(String key) async => _values.containsKey(key);

  @override
  Future<void> deleteAll() async => _values.clear();

  @override
  Future<void> deleteKey(String key) async => _values.remove(key);

  @override
  Future<Map<String, String>> readAll() async => Map<String, String>.from(_values);

  @override
  Future<String?> readValue(String key) async => _values[key];

  @override
  Future<void> writeValue(String key, String value) async => _values[key] = value;
}

class FakeDeviceInfoProvider implements DeviceInfoProvider {
  @override
  Future<Map<String, dynamic>> appInfo() async => <String, dynamic>{'name': 'msgr', 'version': '1.0.0'};

  @override
  Future<Map<String, dynamic>> deviceInfo() async => <String, dynamic>{'model': 'test-device'};
}

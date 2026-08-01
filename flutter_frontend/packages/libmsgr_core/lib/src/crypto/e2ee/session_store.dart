/// Persistence port for E2EE ratchet / trust / device list state.
abstract class E2eeSessionStore {
  Future<void> upsertRatchet({
    required String peerProfileId,
    required String peerDeviceId,
    required Map<String, dynamic> sessionJson,
    String? pendingEkPrivate,
    List<String>? pendingPlaintexts,
  });

  Future<Map<String, dynamic>?> getRatchetRow(
    String peerProfileId,
    String peerDeviceId,
  );

  Future<List<Map<String, dynamic>>> getRatchetsForProfile(
    String peerProfileId,
  );

  Future<void> upsertDeviceList(String profileId, Iterable<String> deviceIds);

  Future<List<String>> getDeviceList(String profileId);

  Future<void> upsertTrust({
    required String deviceId,
    required String fingerprint,
    required String trustLevel,
  });

  Future<Map<String, dynamic>?> getTrust(String deviceId);

  Future<void> upsertOwnDevice({
    required String deviceId,
    required String identityPrivate,
    required String identityPublic,
    String? signedPrekeyPrivate,
    String? signedPrekeyPublic,
    int? signedPrekeyId,
    String? oneTimePrekeysJson,
  });
}

/// In-memory store for unit/integration tests.
class MemoryE2eeSessionStore implements E2eeSessionStore {
  final Map<String, Map<String, dynamic>> _ratchets = {};
  final Map<String, Set<String>> _devices = {};
  final Map<String, Map<String, dynamic>> _trust = {};
  final Map<String, Map<String, dynamic>> _own = {};

  String _rk(String profileId, String deviceId) => '$profileId::$deviceId';

  @override
  Future<void> upsertRatchet({
    required String peerProfileId,
    required String peerDeviceId,
    required Map<String, dynamic> sessionJson,
    String? pendingEkPrivate,
    List<String>? pendingPlaintexts,
  }) async {
    _ratchets[_rk(peerProfileId, peerDeviceId)] = {
      'peer_profile_id': peerProfileId,
      'peer_device_id': peerDeviceId,
      'session_json': sessionJson,
      'pending_ek_private': pendingEkPrivate,
      'pending_plaintext_json': pendingPlaintexts,
    };
  }

  @override
  Future<Map<String, dynamic>?> getRatchetRow(
    String peerProfileId,
    String peerDeviceId,
  ) async {
    final row = _ratchets[_rk(peerProfileId, peerDeviceId)];
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  @override
  Future<List<Map<String, dynamic>>> getRatchetsForProfile(
    String peerProfileId,
  ) async {
    return _ratchets.values
        .where((r) => r['peer_profile_id'] == peerProfileId)
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  @override
  Future<void> upsertDeviceList(
    String profileId,
    Iterable<String> deviceIds,
  ) async {
    _devices.putIfAbsent(profileId, () => <String>{}).addAll(deviceIds);
  }

  @override
  Future<List<String>> getDeviceList(String profileId) async =>
      (_devices[profileId] ?? const <String>{}).toList();

  @override
  Future<void> upsertTrust({
    required String deviceId,
    required String fingerprint,
    required String trustLevel,
  }) async {
    _trust[deviceId] = {
      'device_id': deviceId,
      'fingerprint': fingerprint,
      'trust_level': trustLevel,
    };
  }

  @override
  Future<Map<String, dynamic>?> getTrust(String deviceId) async => _trust[deviceId];

  @override
  Future<void> upsertOwnDevice({
    required String deviceId,
    required String identityPrivate,
    required String identityPublic,
    String? signedPrekeyPrivate,
    String? signedPrekeyPublic,
    int? signedPrekeyId,
    String? oneTimePrekeysJson,
  }) async {
    _own[deviceId] = {
      'device_id': deviceId,
      'identity_private': identityPrivate,
      'identity_public': identityPublic,
    };
  }
}

import 'dart:convert';

import 'package:libmsgr_core/libmsgr_core.dart';

import '../database/daos/omemo_dao.dart';

export 'package:libmsgr_core/libmsgr_core.dart'
    show E2eeService, E2eeSendResult, E2eeReceiveResult, E2eeSessionStore;

/// Adapts [OmemoDao] to [E2eeSessionStore] for SQLCipher persistence.
class OmemoE2eeSessionStore implements E2eeSessionStore {
  OmemoE2eeSessionStore(this._dao);

  final OmemoDao _dao;

  @override
  Future<void> upsertRatchet({
    required String peerProfileId,
    required String peerDeviceId,
    required Map<String, dynamic> sessionJson,
    String? pendingEkPrivate,
    List<String>? pendingPlaintexts,
  }) {
    return _dao.upsertRatchet(
      peerProfileId: peerProfileId,
      peerDeviceId: peerDeviceId,
      sessionJson: sessionJson,
      pendingEkPrivate: pendingEkPrivate,
      pendingPlaintexts: pendingPlaintexts,
    );
  }

  @override
  Future<Map<String, dynamic>?> getRatchetRow(
    String peerProfileId,
    String peerDeviceId,
  ) async {
    final row = await _dao.getRatchetRow(peerProfileId, peerDeviceId);
    if (row == null) return null;
    // Keep session_json as encoded string; E2eeService parses both forms.
    return row;
  }

  @override
  Future<List<Map<String, dynamic>>> getRatchetsForProfile(
    String peerProfileId,
  ) =>
      _dao.getRatchetsForProfile(peerProfileId);

  @override
  Future<void> upsertDeviceList(String profileId, Iterable<String> deviceIds) =>
      _dao.upsertDeviceList(profileId, deviceIds);

  @override
  Future<List<String>> getDeviceList(String profileId) =>
      _dao.getDeviceList(profileId);

  @override
  Future<void> upsertTrust({
    required String deviceId,
    required String fingerprint,
    required String trustLevel,
  }) =>
      _dao.upsertTrust(
        deviceId: deviceId,
        fingerprint: fingerprint,
        trustLevel: trustLevel,
      );

  @override
  Future<Map<String, dynamic>?> getTrust(String deviceId) =>
      _dao.getTrust(deviceId);

  @override
  Future<void> upsertOwnDevice({
    required String deviceId,
    required String identityPrivate,
    required String identityPublic,
    String? signedPrekeyPrivate,
    String? signedPrekeyPublic,
    int? signedPrekeyId,
    String? oneTimePrekeysJson,
  }) =>
      _dao.upsertOwnDevice(
        deviceId: deviceId,
        identityPrivate: identityPrivate,
        identityPublic: identityPublic,
        signedPrekeyPrivate: signedPrekeyPrivate,
        signedPrekeyPublic: signedPrekeyPublic,
        signedPrekeyId: signedPrekeyId,
        oneTimePrekeysJson: oneTimePrekeysJson,
      );
}

/// Convenience constructor wiring KeyManager + SQL OmemoDao.
E2eeService createSqlE2eeService({
  required KeyManager keyManager,
  required OmemoDao dao,
}) {
  return E2eeService(
    keyManager: keyManager,
    store: OmemoE2eeSessionStore(dao),
  );
}

/// Helper retained for call sites that previously json-encoded manually.
String encodeSessionJson(Map<String, dynamic> sessionJson) =>
    jsonEncode(sessionJson);

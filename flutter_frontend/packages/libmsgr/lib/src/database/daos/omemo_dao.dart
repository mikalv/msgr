import 'dart:convert';

import 'package:libmsgr/src/database/constants.dart';
import 'package:libmsgr/src/storage/storage_interface.dart';

class OmemoDao {
  OmemoDao(this._db);

  final DatabaseConnection _db;

  Future<void> upsertRatchet({
    required String peerProfileId,
    required String peerDeviceId,
    required Map<String, dynamic> sessionJson,
    String? pendingEkPrivate,
    List<String>? pendingPlaintexts,
  }) async {
    await _db.insert(
      omemoRatchetsTable,
      {
        'peer_profile_id': peerProfileId,
        'peer_device_id': peerDeviceId,
        'session_json': jsonEncode(sessionJson),
        'pending_ek_private': pendingEkPrivate,
        'pending_plaintext_json':
            pendingPlaintexts == null ? null : jsonEncode(pendingPlaintexts),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getRatchetRow(
    String peerProfileId,
    String peerDeviceId,
  ) async {
    final rows = await _db.query(
      omemoRatchetsTable,
      where: 'peer_profile_id = ? AND peer_device_id = ?',
      whereArgs: [peerProfileId, peerDeviceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> getRatchetsForProfile(
    String peerProfileId,
  ) async {
    final rows = await _db.query(
      omemoRatchetsTable,
      where: 'peer_profile_id = ?',
      whereArgs: [peerProfileId],
    );
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> upsertDeviceList(String profileId, Iterable<String> deviceIds) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final batch = _db.batch();
    for (final deviceId in deviceIds) {
      batch.insert(
        omemoDeviceListTable,
        {
          'profile_id': profileId,
          'device_id': deviceId,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<String>> getDeviceList(String profileId) async {
    final rows = await _db.query(
      omemoDeviceListTable,
      columns: ['device_id'],
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );
    return rows.map((r) => r['device_id']! as String).toList();
  }

  Future<void> upsertTrust({
    required String deviceId,
    required String fingerprint,
    required String trustLevel,
  }) async {
    await _db.insert(
      omemoTrustTable,
      {
        'device_id': deviceId,
        'fingerprint': fingerprint,
        'trust_level': trustLevel,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getTrust(String deviceId) async {
    final rows = await _db.query(
      omemoTrustTable,
      where: 'device_id = ?',
      whereArgs: [deviceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<void> upsertOwnDevice({
    required String deviceId,
    required String identityPrivate,
    required String identityPublic,
    String? signedPrekeyPrivate,
    String? signedPrekeyPublic,
    int? signedPrekeyId,
    String? oneTimePrekeysJson,
  }) async {
    await _db.insert(
      omemoDevicesTable,
      {
        'device_id': deviceId,
        'identity_private': identityPrivate,
        'identity_public': identityPublic,
        'signed_prekey_private': signedPrekeyPrivate,
        'signed_prekey_public': signedPrekeyPublic,
        'signed_prekey_id': signedPrekeyId,
        'one_time_prekeys_json': oneTimePrekeysJson,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

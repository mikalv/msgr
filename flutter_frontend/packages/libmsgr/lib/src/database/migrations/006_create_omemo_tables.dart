import 'package:libmsgr/src/database/constants.dart';
import 'package:libmsgr/src/database/database.dart';
import 'package:libmsgr/src/storage/storage_interface.dart';
import 'package:logging/logging.dart';

Future<void> upgradeFromV7ToV8(DatabaseMigrationData data) async {
  final (DatabaseConnection db, Logger log) = data;
  log.info('Creating OMEMO/E2EE tables');
  await createOmemoTables(db);
}

Future<void> createOmemoTables(DatabaseConnection db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS $omemoDevicesTable (
      device_id TEXT NOT NULL PRIMARY KEY,
      identity_private TEXT NOT NULL,
      identity_public TEXT NOT NULL,
      signed_prekey_private TEXT,
      signed_prekey_public TEXT,
      signed_prekey_id INTEGER,
      one_time_prekeys_json TEXT,
      updated_at TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS $omemoDeviceListTable (
      profile_id TEXT NOT NULL,
      device_id TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      PRIMARY KEY (profile_id, device_id)
    )
  ''');

  await db.execute(
    'CREATE INDEX IF NOT EXISTS omemo_device_list_profile_idx '
    'ON $omemoDeviceListTable(profile_id)',
  );

  await db.execute('''
    CREATE TABLE IF NOT EXISTS $omemoRatchetsTable (
      peer_profile_id TEXT NOT NULL,
      peer_device_id TEXT NOT NULL,
      session_json TEXT NOT NULL,
      pending_ek_private TEXT,
      pending_plaintext_json TEXT,
      updated_at TEXT NOT NULL,
      PRIMARY KEY (peer_profile_id, peer_device_id)
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS $omemoTrustTable (
      device_id TEXT NOT NULL PRIMARY KEY,
      fingerprint TEXT NOT NULL,
      trust_level TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
}

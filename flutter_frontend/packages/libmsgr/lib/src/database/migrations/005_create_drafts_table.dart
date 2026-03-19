import 'package:libmsgr/src/database/constants.dart';
import 'package:libmsgr/src/database/database.dart';
import 'package:libmsgr/src/storage/storage_interface.dart';
import 'package:logging/logging.dart';

Future<void> upgradeFromV6ToV7(DatabaseMigrationData data) async {
  final (DatabaseConnection db, Logger log) = data;

  log.info('Creating $draftsTable table for persistent draft messages');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS $draftsTable (
      channel_id TEXT NOT NULL,
      team_slug TEXT NOT NULL,
      content TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      PRIMARY KEY (channel_id, team_slug)
    )
  ''');

  await db.execute(
    'CREATE INDEX IF NOT EXISTS drafts_team_idx ON $draftsTable(team_slug)',
  );
}

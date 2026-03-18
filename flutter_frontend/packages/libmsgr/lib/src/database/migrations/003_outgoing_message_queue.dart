import 'package:libmsgr/src/database/constants.dart';
import 'package:libmsgr/src/database/database.dart';
import 'package:libmsgr/src/storage/storage_interface.dart';
import 'package:logging/logging.dart';

Future<void> upgradeFromV4ToV5(DatabaseMigrationData data) async {
  final (DatabaseConnection db, Logger log) = data;

  log.info('Adding $outgoingMessagesTable table for durable outgoing messages');

  await db.execute(
    '''
    CREATE TABLE IF NOT EXISTS $outgoingMessagesTable (
      message_id TEXT NOT NULL,
      team_name TEXT NOT NULL,
      topic TEXT NOT NULL,
      payload TEXT NOT NULL,
      last_attempt_at TEXT,
      attempt_count INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (message_id, team_name)
    )''',
  );

  await db.execute(
    'CREATE INDEX IF NOT EXISTS outgoing_messages_team_idx ON $outgoingMessagesTable(team_name)',
  );
}

import 'package:libmsgr/src/database/constants.dart';
import 'package:libmsgr/src/database/database.dart';

Future<void> upgradeFromV2ToV3(DatabaseMigrationData data) async {
  final (db, log) = data;

  log.info('Creating contacts and messages tables');

  await db.execute(
    '''
    CREATE TABLE IF NOT EXISTS $contactsTable (
      id TEXT NOT NULL,
      team_name TEXT NOT NULL,
      uid TEXT NOT NULL,
      username TEXT NOT NULL,
      first_name TEXT,
      last_name TEXT,
      status TEXT,
      avatar_url TEXT,
      settings TEXT,
      roles TEXT,
      inserted_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      PRIMARY KEY (id, team_name)
    )''',
  );

  await db.execute(
    'CREATE INDEX IF NOT EXISTS contacts_team_idx ON $contactsTable(team_name)',
  );

  await db.execute(
    '''
    CREATE TABLE IF NOT EXISTS $messagesTable (
      id TEXT NOT NULL,
      team_name TEXT NOT NULL,
      content TEXT NOT NULL,
      profile_id TEXT NOT NULL,
      conversation_id TEXT,
      room_id TEXT,
      inserted_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      is_system_msg INTEGER NOT NULL,
      in_reply_to_id TEXT,
      is_server_ack INTEGER NOT NULL,
      is_msg_read INTEGER NOT NULL,
      PRIMARY KEY (id, team_name)
    )''',
  );

  await db.execute(
    'CREATE INDEX IF NOT EXISTS messages_conversation_idx ON $messagesTable(team_name, conversation_id)',
  );

  await db.execute(
    'CREATE INDEX IF NOT EXISTS messages_room_idx ON $messagesTable(team_name, room_id)',
  );

  await db.execute(
    'CREATE INDEX IF NOT EXISTS messages_profile_idx ON $messagesTable(team_name, profile_id)',
  );
}

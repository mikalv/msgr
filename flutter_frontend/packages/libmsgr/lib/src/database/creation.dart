import 'package:libmsgr/src/database/constants.dart';
import 'package:sqflite_sqlcipher/sqlite_api.dart';

Future<void> configureDatabase(Database db) async {
  await db.execute('PRAGMA foreign_keys = OFF');
}

Future<void> createDatabase(Database db, int version) async {
  // XMPP state
  await db.execute(
    '''
    CREATE TABLE $xmppStateTable (
      key        TEXT NOT NULL,
      accountJid TEXT NOT NULL,
      value TEXT,
      PRIMARY KEY (key, accountJid)
    )''',
  );

  // Settings
  await db.execute(
    '''
    CREATE TABLE $preferenceTable (
      key TEXT NOT NULL PRIMARY KEY,
      type INTEGER NOT NULL,
      value TEXT NULL
    )''',
  );

  await db.execute(
    '''
    CREATE TABLE $contactsTable (
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
    'CREATE INDEX contacts_team_idx ON $contactsTable(team_name)',
  );

  await db.execute(
    '''
    CREATE TABLE $messagesTable (
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
    'CREATE INDEX messages_conversation_idx ON $messagesTable(team_name, conversation_id)',
  );

  await db.execute(
    'CREATE INDEX messages_room_idx ON $messagesTable(team_name, room_id)',
  );

  await db.execute(
    'CREATE INDEX messages_profile_idx ON $messagesTable(team_name, profile_id)',
  );
}

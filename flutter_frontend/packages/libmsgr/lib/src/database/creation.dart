import 'package:libmsgr/src/database/constants.dart';
import 'package:libmsgr/src/storage/storage_interface.dart';

Future<void> configureDatabase(DatabaseConnection db) async {
  await db.execute('PRAGMA foreign_keys = OFF');
}

Future<void> createDatabase(DatabaseConnection db) async {
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
      uid TEXT,
      username TEXT NOT NULL,
      name TEXT,
      slug TEXT,
      mode TEXT,
      first_name TEXT,
      last_name TEXT,
      status TEXT,
      avatar_url TEXT,
      settings TEXT,
      roles TEXT,
      theme TEXT,
      notification_policy TEXT,
      security_policy TEXT,
      is_active INTEGER NOT NULL DEFAULT 0,
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
      channel_id TEXT,
      inserted_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      is_system_msg INTEGER NOT NULL,
      in_reply_to_id TEXT,
      is_server_ack INTEGER NOT NULL,
      is_msg_read INTEGER NOT NULL,
      delivery_status TEXT NOT NULL,
      PRIMARY KEY (id, team_name)
    )''',
  );

  await db.execute(
    'CREATE INDEX messages_conversation_idx ON $messagesTable(team_name, conversation_id)',
  );

  await db.execute(
    'CREATE INDEX messages_channel_idx ON $messagesTable(team_name, channel_id)',
  );

  await db.execute(
    'CREATE INDEX messages_profile_idx ON $messagesTable(team_name, profile_id)',
  );

  await db.execute(
    '''
    CREATE TABLE $outgoingMessagesTable (
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
    'CREATE INDEX outgoing_messages_team_idx ON $outgoingMessagesTable(team_name)',
  );
}

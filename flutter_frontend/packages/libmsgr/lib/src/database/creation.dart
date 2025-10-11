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
}

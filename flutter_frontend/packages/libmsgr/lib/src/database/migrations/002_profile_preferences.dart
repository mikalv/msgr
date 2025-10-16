import 'package:libmsgr/src/database/constants.dart';
import 'package:libmsgr/src/database/database.dart';
import 'package:logging/logging.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

Future<void> upgradeFromV3ToV4(DatabaseMigrationData data) async {
  final (Database db, Logger log) = data;

  log.info('Adding profile preference columns to $contactsTable');

  Future<void> addColumn(String name, String definition) async {
    try {
      await db.execute(
        'ALTER TABLE $contactsTable ADD COLUMN $name $definition',
      );
    } on DatabaseException catch (error) {
      if (!error.toString().contains('duplicate column name')) {
        rethrow;
      }
      log.fine('Column $name already exists');
    }
  }

  await addColumn('name', 'TEXT');
  await addColumn('slug', 'TEXT');
  await addColumn('mode', 'TEXT');
  await addColumn('theme', 'TEXT');
  await addColumn('notification_policy', 'TEXT');
  await addColumn('security_policy', 'TEXT');
  await addColumn('is_active', 'INTEGER NOT NULL DEFAULT 0');
  await addColumn('uid', 'TEXT');
}

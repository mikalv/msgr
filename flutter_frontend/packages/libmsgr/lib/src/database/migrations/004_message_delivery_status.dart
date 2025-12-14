import 'package:libmsgr/src/database/constants.dart';
import 'package:libmsgr/src/database/database.dart';
import 'package:logging/logging.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

Future<void> upgradeFromV5ToV6(DatabaseMigrationData data) async {
  final (Database db, Logger log) = data;

  log.info('Adding delivery_status column to $messagesTable');

  await db.execute(
    'ALTER TABLE $messagesTable ADD COLUMN delivery_status TEXT NOT NULL DEFAULT "delivered"',
  );

  await db.execute(
    '''
    UPDATE $messagesTable
    SET delivery_status = CASE
      WHEN is_server_ack = 1 THEN 'delivered'
      ELSE 'pending'
    END
    '''
  );
}

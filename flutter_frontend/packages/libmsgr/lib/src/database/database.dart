import 'package:libmsgr/src/database/creation.dart';
import 'package:libmsgr/src/database/migration.dart';
import 'package:libmsgr/src/database/migrations/000_initial_migration.dart';
import 'package:libmsgr/src/database/migrations/001_add_messages_and_contacts.dart';
import 'package:logging/logging.dart';
import 'package:sqflite_common/src/sql_builder.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart' as path;

/// Data passed to the migrations.
typedef DatabaseMigrationData = (Database, Logger);

//@internal
const List<Migration<DatabaseMigrationData>> migrations = [
  Migration(2, upgradeFromV1ToV2),
  Migration(3, upgradeFromV2ToV3),
];

class DatabaseService {
  /// Logger.
  final Logger _log = Logger('DatabaseService');

  /// The database.
  late Database database;

  Database get instance => database;

  Future<void> initialize() async {
    final dbPath = path.join(
      await getDatabasesPath(),
      'msgr.db',
    );
    final dbPassword = "hmm";
    //await GetIt.I.get<XmppStateService>().getOrCreateDatabaseKey();

    // Just some sanity checks
    final version = migrations.last.version;
    assert(
      migrations.every((migration) => migration.version <= version),
      "Every migration's version must be smaller or equal to the last version",
    );
    assert(
      migrations
          .sublist(0, migrations.length - 1)
          .every((migration) => migration.version < version),
      'The last migration must have the largest version',
    );

    database = await openDatabase(
      dbPath,
      password: dbPassword,
      version: version,
      onCreate: createDatabase,
      onConfigure: (db) async {
        // In order to do schema changes during database upgrades, we disable foreign
        // keys in the onConfigure phase, but re-enable them here.
        // See https://github.com/tekartik/sqflite/issues/624#issuecomment-813324273
        // for the "solution".
        await db.execute('PRAGMA foreign_keys = OFF');
      },
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        final logger = Logger('DatabaseMigration');
        await runMigrations(
          _log,
          (db, logger),
          migrations,
          oldVersion,
          'database',
        );
      },
    );

    _log.finest('Database setup done');
  }
}

extension DatabaseHelpers on Database {
  /// Count the number of rows in [table] where [where] with the arguments [whereArgs]
  /// matches.
  Future<int> count(
    String table,
    String where,
    List<Object?> whereArgs,
  ) async {
    return Sqflite.firstIntValue(
      await rawQuery(
        'SELECT COUNT(*) FROM $table WHERE $where',
        whereArgs,
      ),
    )!;
  }

  /// Like insert but returns the affected row.
  Future<Map<String, Object?>> insertAndReturn(
    String table,
    Map<String, Object?> values,
  ) async {
    final q = SqlBuilder.insert(
      table,
      values,
    );

    final result = await rawQuery(
      '${q.sql} RETURNING *',
      q.arguments,
    );
    assert(result.length == 1, 'Only one row must be returned');
    return result.first;
  }

  /// Like update but returns the affected row.
  Future<Map<String, Object?>> updateAndReturn(
    String table,
    Map<String, Object?> values, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final q = SqlBuilder.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
    );

    final result = await rawQuery(
      '${q.sql} RETURNING *',
      q.arguments,
    );
    assert(result.length == 1, 'Only one row must be returned');
    return result.first;
  }
}

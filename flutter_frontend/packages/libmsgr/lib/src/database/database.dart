import 'package:libmsgr/src/database/creation.dart';
import 'package:libmsgr/src/database/migration.dart';
import 'package:libmsgr/src/database/migrations/000_initial_migration.dart';
import 'package:libmsgr/src/database/migrations/001_add_messages_and_contacts.dart';
import 'package:libmsgr/src/database/migrations/002_profile_preferences.dart';
import 'package:libmsgr/src/database/migrations/003_outgoing_message_queue.dart';
import 'package:libmsgr/src/database/migrations/004_message_delivery_status.dart';
import 'package:libmsgr/src/database/migrations/005_create_drafts_table.dart';
import 'package:libmsgr/src/storage/storage_interface.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

/// Data passed to the migrations.
typedef DatabaseMigrationData = (DatabaseConnection, Logger);

//@internal
const List<Migration<DatabaseMigrationData>> migrations = [
  Migration(2, upgradeFromV1ToV2),
  Migration(3, upgradeFromV2ToV3),
  Migration(4, upgradeFromV3ToV4),
  Migration(5, upgradeFromV4ToV5),
  Migration(6, upgradeFromV5ToV6),
  Migration(7, upgradeFromV6ToV7),
];

class DatabaseService {
  /// Logger.
  final Logger _log = Logger('DatabaseService');

  /// The storage provider (injected).
  final StorageProvider _storageProvider;

  /// The path provider (injected).
  final PathProvider _pathProvider;

  /// The database connection.
  late DatabaseConnection database;

  DatabaseConnection get instance => database;

  /// Create a new DatabaseService with injected dependencies.
  ///
  /// [storageProvider] - Implementation of database storage (sqflite, FFI, etc)
  /// [pathProvider] - Implementation of path resolution (Flutter, CLI, etc)
  DatabaseService({
    required StorageProvider storageProvider,
    required PathProvider pathProvider,
  })  : _storageProvider = storageProvider,
        _pathProvider = pathProvider;

  Future<void> initialize() async {
    // Use shared directory for database so both apps can access it
    final sharedDir = await _pathProvider.getApplicationSupportDirectory();
    final dbPath = path.join(sharedDir, 'msgr.db');

    // TODO: Generate and securely store database password
    // For now using hardcoded password (should be changed to keychain-based)
    final dbPassword = "hmm";

    _log.info('Database path: $dbPath');

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

    database = await _storageProvider.openDatabase(
      DatabaseConfig(
        filename: dbPath,
        password: dbPassword,
        version: version,
      ),
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

  /// Close the database connection.
  Future<void> close() async {
    await _storageProvider.close();
  }
}

// Note: DatabaseHelpers extension is now defined in storage_interface.dart
// and applies to DatabaseConnection instead of sqflite's Database

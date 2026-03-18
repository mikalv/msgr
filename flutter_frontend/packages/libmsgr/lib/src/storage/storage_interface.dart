import 'package:logging/logging.dart';

/// Configuration for initializing a database.
class DatabaseConfig {
  final String filename;
  final String? password;
  final int version;

  const DatabaseConfig({
    required this.filename,
    this.password,
    required this.version,
  });
}

/// Abstract interface for resolving file system paths.
///
/// Different implementations:
/// - Flutter apps: Use path_provider
/// - CLI/Desktop: Use platform-specific defaults or XDG directories
abstract class PathProvider {
  /// Get the application support directory where databases and config are stored.
  Future<String> getApplicationSupportDirectory();

  /// Get the temporary directory for cache and temp files.
  Future<String> getTemporaryDirectory();
}

/// Abstract interface for database operations.
///
/// This allows libmsgr to be platform-agnostic while still supporting:
/// - Flutter apps: sqflite/sqflite_sqlcipher
/// - CLI: sqflite_common_ffi
/// - Tests: in-memory databases
abstract class StorageProvider {
  /// Open or create a database with the given configuration.
  ///
  /// [config] - Database configuration including filename, password, version
  /// [onCreate] - Called when database is created for the first time
  /// [onConfigure] - Called before any other operations
  /// [onOpen] - Called after database is opened
  /// [onUpgrade] - Called when database version increases
  Future<DatabaseConnection> openDatabase(
    DatabaseConfig config, {
    required Future<void> Function(DatabaseConnection db) onCreate,
    Future<void> Function(DatabaseConnection db)? onConfigure,
    Future<void> Function(DatabaseConnection db)? onOpen,
    Future<void> Function(DatabaseConnection db, int oldVersion, int newVersion)? onUpgrade,
  });

  /// Close all open database connections.
  Future<void> close();
}

/// Abstract interface for database connections.
///
/// This wraps the underlying database (sqflite.Database or similar)
/// and provides a common interface for queries.
abstract class DatabaseConnection {
  /// Execute a raw SQL query that returns results.
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]);

  /// Execute a raw SQL statement that doesn't return results.
  Future<void> execute(
    String sql, [
    List<Object?>? arguments,
  ]);

  /// Insert a row into a table.
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  });

  /// Query rows from a table.
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  });

  /// Update rows in a table.
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  });

  /// Delete rows from a table.
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  });

  /// Execute multiple operations in a transaction.
  Future<T> transaction<T>(
    Future<T> Function(DatabaseConnection txn) action, {
    bool? exclusive,
  });

  /// Execute a batch of operations.
  Batch batch();
}

/// Batch operations interface.
abstract class Batch {
  void insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  });

  void update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  });

  void delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  });

  void rawInsert(String sql, [List<Object?>? arguments]);
  void rawUpdate(String sql, [List<Object?>? arguments]);
  void rawDelete(String sql, [List<Object?>? arguments]);

  Future<List<Object?>> commit({bool? exclusive, bool? noResult});
}

/// Conflict resolution algorithms for insert/update operations.
enum ConflictAlgorithm {
  rollback,
  abort,
  fail,
  ignore,
  replace,
}

/// Helper extension for common database operations.
extension DatabaseHelpers on DatabaseConnection {
  /// Count the number of rows in [table] where [where] with the arguments [whereArgs]
  /// matches.
  Future<int> count(
    String table,
    String where,
    List<Object?> whereArgs,
  ) async {
    final result = await rawQuery(
      'SELECT COUNT(*) FROM $table WHERE $where',
      whereArgs,
    );

    if (result.isEmpty) return 0;
    final firstValue = result.first.values.first;
    return firstValue as int;
  }

  /// Like insert but returns the affected row.
  Future<Map<String, Object?>> insertAndReturn(
    String table,
    Map<String, Object?> values,
  ) async {
    // Build INSERT SQL manually since we need RETURNING clause
    final columns = values.keys.join(', ');
    final placeholders = List.filled(values.length, '?').join(', ');
    final sql = 'INSERT INTO $table ($columns) VALUES ($placeholders) RETURNING *';

    final result = await rawQuery(sql, values.values.toList());
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
    // Build UPDATE SQL manually since we need RETURNING clause
    final setClauses = values.keys.map((key) => '$key = ?').join(', ');
    final sql = 'UPDATE $table SET $setClauses WHERE $where RETURNING *';

    final arguments = [...values.values, ...whereArgs];
    final result = await rawQuery(sql, arguments);
    assert(result.length == 1, 'Only one row must be returned');
    return result.first;
  }
}

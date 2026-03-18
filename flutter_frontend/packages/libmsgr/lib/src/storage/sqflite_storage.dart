import 'package:sqflite_sqlcipher/sqflite.dart' as sqflite;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:libmsgr/src/storage/storage_interface.dart';

/// Flutter-specific implementation using sqflite_sqlcipher.
class FlutterPathProvider implements PathProvider {
  @override
  Future<String> getApplicationSupportDirectory() async {
    final dir = await path_provider.getApplicationSupportDirectory();
    return dir.path;
  }

  @override
  Future<String> getTemporaryDirectory() async {
    final dir = await path_provider.getTemporaryDirectory();
    return dir.path;
  }
}

/// Flutter-specific storage implementation using sqflite_sqlcipher.
class SqfliteStorageProvider implements StorageProvider {
  final Map<String, SqfliteDatabaseConnection> _connections = {};

  @override
  Future<DatabaseConnection> openDatabase(
    DatabaseConfig config, {
    required Future<void> Function(DatabaseConnection db) onCreate,
    Future<void> Function(DatabaseConnection db)? onConfigure,
    Future<void> Function(DatabaseConnection db)? onOpen,
    Future<void> Function(DatabaseConnection db, int oldVersion, int newVersion)? onUpgrade,
  }) async {
    final db = await sqflite.openDatabase(
      config.filename,
      password: config.password,
      version: config.version,
      onCreate: (db, version) async {
        final conn = SqfliteDatabaseConnection(db);
        await onCreate(conn);
      },
      onConfigure: onConfigure != null
          ? (db) async {
              final conn = SqfliteDatabaseConnection(db);
              await onConfigure(conn);
            }
          : null,
      onOpen: onOpen != null
          ? (db) async {
              final conn = SqfliteDatabaseConnection(db);
              await onOpen(conn);
            }
          : null,
      onUpgrade: onUpgrade != null
          ? (db, oldVersion, newVersion) async {
              final conn = SqfliteDatabaseConnection(db);
              await onUpgrade(conn, oldVersion, newVersion);
            }
          : null,
    );

    final connection = SqfliteDatabaseConnection(db);
    _connections[config.filename] = connection;
    return connection;
  }

  @override
  Future<void> close() async {
    for (final conn in _connections.values) {
      await conn._db.close();
    }
    _connections.clear();
  }
}

/// Wraps sqflite.Database to implement DatabaseConnection interface.
class SqfliteDatabaseConnection implements DatabaseConnection {
  final sqflite.Database _db;

  SqfliteDatabaseConnection(this._db);

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) =>
      _db.rawQuery(sql, arguments);

  @override
  Future<void> execute(
    String sql, [
    List<Object?>? arguments,
  ]) =>
      _db.execute(sql, arguments);

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      _db.insert(
        table,
        values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: _convertConflictAlgorithm(conflictAlgorithm),
      );

  @override
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
  }) =>
      _db.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      _db.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: _convertConflictAlgorithm(conflictAlgorithm),
      );

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) =>
      _db.delete(
        table,
        where: where,
        whereArgs: whereArgs,
      );

  @override
  Future<T> transaction<T>(
    Future<T> Function(DatabaseConnection txn) action, {
    bool? exclusive,
  }) =>
      _db.transaction(
        (txn) => action(SqfliteDatabaseConnection(txn)),
        exclusive: exclusive,
      );

  @override
  Batch batch() => SqfliteBatch(_db.batch());

  sqflite.ConflictAlgorithm? _convertConflictAlgorithm(
      ConflictAlgorithm? algorithm) {
    if (algorithm == null) return null;
    switch (algorithm) {
      case ConflictAlgorithm.rollback:
        return sqflite.ConflictAlgorithm.rollback;
      case ConflictAlgorithm.abort:
        return sqflite.ConflictAlgorithm.abort;
      case ConflictAlgorithm.fail:
        return sqflite.ConflictAlgorithm.fail;
      case ConflictAlgorithm.ignore:
        return sqflite.ConflictAlgorithm.ignore;
      case ConflictAlgorithm.replace:
        return sqflite.ConflictAlgorithm.replace;
    }
  }
}

/// Wraps sqflite.Batch to implement Batch interface.
class SqfliteBatch implements Batch {
  final sqflite.Batch _batch;

  SqfliteBatch(this._batch);

  @override
  void insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _batch.insert(
      table,
      values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: _convertConflictAlgorithm(conflictAlgorithm),
    );
  }

  @override
  void update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _batch.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: _convertConflictAlgorithm(conflictAlgorithm),
    );
  }

  @override
  void delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    _batch.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  @override
  void rawInsert(String sql, [List<Object?>? arguments]) {
    _batch.rawInsert(sql, arguments);
  }

  @override
  void rawUpdate(String sql, [List<Object?>? arguments]) {
    _batch.rawUpdate(sql, arguments);
  }

  @override
  void rawDelete(String sql, [List<Object?>? arguments]) {
    _batch.rawDelete(sql, arguments);
  }

  @override
  Future<List<Object?>> commit({bool? exclusive, bool? noResult}) =>
      _batch.commit(exclusive: exclusive, noResult: noResult);

  sqflite.ConflictAlgorithm? _convertConflictAlgorithm(
      ConflictAlgorithm? algorithm) {
    if (algorithm == null) return null;
    switch (algorithm) {
      case ConflictAlgorithm.rollback:
        return sqflite.ConflictAlgorithm.rollback;
      case ConflictAlgorithm.abort:
        return sqflite.ConflictAlgorithm.abort;
      case ConflictAlgorithm.fail:
        return sqflite.ConflictAlgorithm.fail;
      case ConflictAlgorithm.ignore:
        return sqflite.ConflictAlgorithm.ignore;
      case ConflictAlgorithm.replace:
        return sqflite.ConflictAlgorithm.replace;
    }
  }
}

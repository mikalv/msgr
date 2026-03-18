import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite_ffi;
import 'package:path/path.dart' as path;
import 'package:libmsgr/src/storage/storage_interface.dart';

/// CLI/Desktop path provider using platform-specific directories.
class CliPathProvider implements PathProvider {
  @override
  Future<String> getApplicationSupportDirectory() async {
    // Use platform-specific config directories
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME']!;
      final dir = Directory('$home/Library/Application Support/msgr');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir.path;
    } else if (Platform.isLinux) {
      // Follow XDG Base Directory specification
      final xdgDataHome = Platform.environment['XDG_DATA_HOME'];
      if (xdgDataHome != null) {
        final dir = Directory('$xdgDataHome/msgr');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir.path;
      }
      final home = Platform.environment['HOME']!;
      final dir = Directory('$home/.local/share/msgr');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir.path;
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA']!;
      final dir = Directory('$appData\\msgr');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir.path;
    } else {
      throw UnsupportedError('Platform not supported');
    }
  }

  @override
  Future<String> getTemporaryDirectory() async {
    return Directory.systemTemp.path;
  }
}

/// CLI/Desktop storage implementation using sqflite_common_ffi.
class FfiStorageProvider implements StorageProvider {
  final Map<String, FfiDatabaseConnection> _connections = {};
  bool _initialized = false;

  FfiStorageProvider() {
    // Initialize FFI for sqflite
    if (!_initialized) {
      sqflite_ffi.sqfliteFfiInit();
      _initialized = true;
    }
  }

  @override
  Future<DatabaseConnection> openDatabase(
    DatabaseConfig config, {
    required Future<void> Function(DatabaseConnection db) onCreate,
    Future<void> Function(DatabaseConnection db)? onConfigure,
    Future<void> Function(DatabaseConnection db)? onOpen,
    Future<void> Function(DatabaseConnection db, int oldVersion, int newVersion)? onUpgrade,
  }) async {
    final databaseFactory = sqflite_ffi.databaseFactoryFfi;

    // Note: sqflite_ffi doesn't support encryption (password parameter)
    // If encryption is needed, we'd need to use a different library
    // or implement SQLCipher bindings

    final db = await databaseFactory.openDatabase(
      config.filename,
      options: sqflite_ffi.OpenDatabaseOptions(
        version: config.version,
        onCreate: (db, version) async {
          final conn = FfiDatabaseConnection(db);
          await onCreate(conn);
        },
        onConfigure: onConfigure != null
            ? (db) async {
                final conn = FfiDatabaseConnection(db);
                await onConfigure(conn);
              }
            : null,
        onOpen: onOpen != null
            ? (db) async {
                final conn = FfiDatabaseConnection(db);
                await onOpen(conn);
              }
            : null,
        onUpgrade: onUpgrade != null
            ? (db, oldVersion, newVersion) async {
                final conn = FfiDatabaseConnection(db);
                await onUpgrade(conn, oldVersion, newVersion);
              }
            : null,
      ),
    );

    final connection = FfiDatabaseConnection(db);
    _connections[config.filename] = connection;
    return connection;
  }

  @override
  Future<void> close() async {
    for (final conn in _connections.values) {
      if (conn._database != null) {
        await conn._database!.close();
      }
    }
    _connections.clear();
  }
}

/// Wraps sqflite_common_ffi.Database to implement DatabaseConnection interface.
class FfiDatabaseConnection implements DatabaseConnection {
  final sqflite_ffi.DatabaseExecutor _db;
  final sqflite_ffi.Database? _database;

  FfiDatabaseConnection(this._db) : _database = _db is sqflite_ffi.Database ? _db : null;

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
  }) {
    if (_database == null) {
      throw StateError('Cannot create transaction on non-database executor');
    }
    return _database!.transaction(
      (txn) => action(FfiDatabaseConnection(txn)),
      exclusive: exclusive,
    );
  }

  @override
  Batch batch() => FfiBatch(_db.batch());

  sqflite_ffi.ConflictAlgorithm? _convertConflictAlgorithm(
      ConflictAlgorithm? algorithm) {
    if (algorithm == null) return null;
    switch (algorithm) {
      case ConflictAlgorithm.rollback:
        return sqflite_ffi.ConflictAlgorithm.rollback;
      case ConflictAlgorithm.abort:
        return sqflite_ffi.ConflictAlgorithm.abort;
      case ConflictAlgorithm.fail:
        return sqflite_ffi.ConflictAlgorithm.fail;
      case ConflictAlgorithm.ignore:
        return sqflite_ffi.ConflictAlgorithm.ignore;
      case ConflictAlgorithm.replace:
        return sqflite_ffi.ConflictAlgorithm.replace;
    }
  }
}

/// Wraps sqflite_common_ffi.Batch to implement Batch interface.
class FfiBatch implements Batch {
  final sqflite_ffi.Batch _batch;

  FfiBatch(this._batch);

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

  sqflite_ffi.ConflictAlgorithm? _convertConflictAlgorithm(
      ConflictAlgorithm? algorithm) {
    if (algorithm == null) return null;
    switch (algorithm) {
      case ConflictAlgorithm.rollback:
        return sqflite_ffi.ConflictAlgorithm.rollback;
      case ConflictAlgorithm.abort:
        return sqflite_ffi.ConflictAlgorithm.abort;
      case ConflictAlgorithm.fail:
        return sqflite_ffi.ConflictAlgorithm.fail;
      case ConflictAlgorithm.ignore:
        return sqflite_ffi.ConflictAlgorithm.ignore;
      case ConflictAlgorithm.replace:
        return sqflite_ffi.ConflictAlgorithm.replace;
    }
  }
}

/// Storage interfaces and implementations for libmsgr.
///
/// This library exports storage abstractions and implementations.
/// Applications should choose the appropriate implementation for their platform:
///
/// - Flutter apps: Use `SqfliteStorageProvider` and `FlutterPathProvider`
///   Import from: package:libmsgr/src/storage/sqflite_storage.dart
/// - CLI/Desktop: Use `FfiStorageProvider` and `CliPathProvider`
library;

// Core interfaces (always available, pure Dart)
export 'src/storage/storage_interface.dart';

// Pure Dart FFI implementation (always available)
export 'src/storage/ffi_storage.dart';

// Note: Flutter storage (sqflite_storage.dart) is NOT exported here because it
// requires Flutter dependencies. Flutter apps must import it directly:
// import 'package:libmsgr/src/storage/sqflite_storage.dart';

# Storage Architecture

## Overview

libmsgr now uses a storage abstraction layer that allows it to work in both Flutter and pure Dart environments (CLI, server, etc.) without requiring Flutter dependencies in the core library.

## Architecture

### Interfaces (`src/storage/storage_interface.dart`)

- **`StorageProvider`**: Abstract interface for database operations (opening, closing databases)
- **`PathProvider`**: Abstract interface for resolving file system paths
- **`DatabaseConnection`**: Abstract interface for database queries and transactions
- **`Batch`**: Abstract interface for batch operations
- **`ConflictAlgorithm`**: Enum for conflict resolution strategies

### Implementations

#### Flutter Implementation (`src/storage/sqflite_storage.dart`)

For Flutter apps:
- `SqfliteStorageProvider` - Uses `sqflite_sqlcipher` for encrypted SQLite
- `FlutterPathProvider` - Uses `path_provider` package
- Requires Flutter packages to be available

#### CLI/Desktop Implementation (`src/storage/ffi_storage.dart`)

For pure Dart CLI and desktop apps:
- `FfiStorageProvider` - Uses `sqflite_common_ffi` (pure Dart FFI bindings)
- `CliPathProvider` - Uses platform-specific config directories:
  - macOS: `~/Library/Application Support/msgr`
  - Linux: `$XDG_DATA_HOME/msgr` or `~/.local/share/msgr`
  - Windows: `%APPDATA%\msgr`
- **Note**: `sqflite_common_ffi` does not support encryption

## Usage

### Flutter Apps

```dart
import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/storage.dart';

void main() async {
  final libmsgr = LibMsgr();

  // Set up storage providers
  libmsgr.storageProvider = SqfliteStorageProvider();
  libmsgr.pathProvider = FlutterPathProvider();

  // Set other dependencies
  libmsgr.sharedPreferences = await SharedPreferences.getInstance();
  libmsgr.secureStorage = FlutterSecureStorage();
  libmsgr.deviceInfoInstance = DeviceInfoPlugin();

  // Bootstrap
  await libmsgr.bootstrapLibrary();

  // Use libmsgr...
}
```

### CLI/Desktop Apps

```dart
import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/storage.dart';

void main() async {
  final libmsgr = LibMsgr();

  // Set up CLI storage providers
  libmsgr.storageProvider = FfiStorageProvider();
  libmsgr.pathProvider = CliPathProvider();

  // Set other dependencies (you'll need CLI implementations)
  libmsgr.sharedPreferences = CliSharedPreferences(); // Your implementation
  libmsgr.secureStorage = CliSecureStorage(); // Your implementation
  libmsgr.deviceInfoInstance = CliDeviceInfo(); // Your implementation

  // Bootstrap
  await libmsgr.bootstrapLibrary();

  // Use libmsgr...
}
```

## Dependencies

### Core libmsgr Dependencies

Pure Dart only:
- `sqflite_common` - Common interfaces (no platform dependencies)
- `path` - Path manipulation
- Other pure Dart packages

### Dev Dependencies (for testing/development)

Flutter-specific (only loaded in Flutter context):
- `sqflite`
- `sqflite_sqlcipher`
- `path_provider`
- `drift_flutter`
- `shared_preferences`

Pure Dart (for CLI testing):
- `sqflite_common_ffi`

## Migration Guide

### For Existing Flutter Apps

Your Flutter app now needs to inject storage providers before bootstrapping:

```dart
// Before
final libmsgr = LibMsgr();
await libmsgr.bootstrapLibrary();

// After
final libmsgr = LibMsgr();
libmsgr.storageProvider = SqfliteStorageProvider();
libmsgr.pathProvider = FlutterPathProvider();
await libmsgr.bootstrapLibrary();
```

### For New CLI Apps

Create implementations of the storage interfaces or use the provided FFI implementations:

```dart
final libmsgr = LibMsgr();
libmsgr.storageProvider = FfiStorageProvider();
libmsgr.pathProvider = CliPathProvider();
// ... set other dependencies
await libmsgr.bootstrapLibrary();
```

## Design Benefits

1. **Pure Dart Core**: libmsgr can now be used in pure Dart environments (CLI tools, servers)
2. **Platform Flexibility**: Easy to add new storage backends (e.g., in-memory for tests, cloud storage)
3. **Dependency Injection**: Clear separation of concerns, easier testing
4. **No Flutter Lock-in**: Core library doesn't require Flutter SDK

## Limitations

- `FfiStorageProvider` does not support encryption (SQLCipher requires native bindings)
- Flutter apps should continue using `SqfliteStorageProvider` for encryption support
- CLI apps using `FfiStorageProvider` have unencrypted databases

## Future Improvements

- Add in-memory storage provider for testing
- Add encryption support for FFI storage (SQLCipher FFI bindings)
- Consider abstracting other platform-specific dependencies (secure storage, shared preferences)

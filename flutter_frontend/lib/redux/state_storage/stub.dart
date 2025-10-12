import 'dart:typed_data';

import 'package:redux_persist/redux_persist.dart';

/// Stub storage engine for Redux Persist.
/// https://pub.dev/documentation/redux_persist/latest/
///
class ReduxStorage extends StorageEngine {
  @override
  Future<Uint8List?> load() {
    // TODO: implement load
    throw UnimplementedError();
  }

  @override
  Future<void> save(Uint8List? data) {
    // TODO: implement save
    throw UnimplementedError();
  }
}

StorageEngine getReduxPersistStorage(log) {
  return ReduxStorage();
}

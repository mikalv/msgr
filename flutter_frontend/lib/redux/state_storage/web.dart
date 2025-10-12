import 'dart:typed_data';
import 'dart:html';
import 'package:redux_persist/redux_persist.dart';

class WebStorage implements StorageEngine {
  /// localStorage key to save to.
  final String key;

  WebStorage([this.key = "app"]);

  @override
  Future<Uint8List> load() =>
      Future.value(stringToUint8List(window.localStorage[key]));

  @override
  Future<void> save(Uint8List? data) async {
    window.localStorage[key] = uint8ListToString(data)!;
  }
}

StorageEngine getReduxPersistStorage(log) {
  return WebStorage();
}

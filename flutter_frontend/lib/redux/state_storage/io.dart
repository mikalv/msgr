import 'dart:io';
import 'package:messngr/config/app_constants.dart';
import 'package:redux_persist/redux_persist.dart';

StorageEngine getReduxPersistStorage(log) {
  final file = File(appStatePersistFile);
  log.info('State file: ${file.absolute}');
  return FileStorage(file);
}

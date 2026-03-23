import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String?> readApnsToken() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/apns_token.txt');
    if (await file.exists()) {
      return (await file.readAsString()).trim();
    }
  } catch (_) {}
  return null;
}

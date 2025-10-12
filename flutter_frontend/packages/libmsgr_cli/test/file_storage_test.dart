import 'dart:io';

import 'package:libmsgr_cli/libmsgr_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('msgr_cli_test');
  });

  tearDown(() async {
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test('FileSecureStorage persists values', () async {
    final storage = FileSecureStorage(temp);
    expect(await storage.containsKey('token'), isFalse);

    await storage.writeValue('token', 'abc');
    expect(await storage.containsKey('token'), isTrue);
    expect(await storage.readValue('token'), 'abc');

    final reloaded = FileSecureStorage(temp);
    expect(await reloaded.readValue('token'), 'abc');
  });

  test('FileKeyValueStore persists mixed types', () async {
    final prefs = FileKeyValueStore(temp);
    await prefs.setBool('bool', true);
    await prefs.setDouble('double', 1.5);
    await prefs.setInt('int', 42);
    await prefs.setString('string', 'value');
    await prefs.setStringList('list', ['a', 'b']);

    final reloaded = FileKeyValueStore(temp);
    expect(await reloaded.getBool('bool'), isTrue);
    expect(await reloaded.getDouble('double'), 1.5);
    expect(await reloaded.getInt('int'), 42);
    expect(await reloaded.getString('string'), 'value');
    expect(await reloaded.getStringList('list'), ['a', 'b']);
  });
}

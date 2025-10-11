import 'package:test/test.dart';

import '../../tool/src/memory_adapters.dart';

void main() {
  group('MemorySecureStorage', () {
    test('stores and retrieves values', () async {
      final storage = MemorySecureStorage();
      expect(await storage.containsKey('token'), isFalse);

      await storage.writeValue('token', 'value');
      expect(await storage.containsKey('token'), isTrue);
      expect(await storage.readValue('token'), 'value');

      final snapshot = await storage.readAll();
      expect(snapshot, containsPair('token', 'value'));

      await storage.deleteKey('token');
      expect(await storage.containsKey('token'), isFalse);
    });

    test('deleteAll clears stored keys', () async {
      final storage = MemorySecureStorage();
      await storage.writeValue('a', '1');
      await storage.writeValue('b', '2');

      await storage.deleteAll();
      expect(await storage.readAll(), isEmpty);
    });
  });

  group('MemorySharedPreferences', () {
    test('supports primitive setters and getters', () async {
      final prefs = MemorySharedPreferences();
      await prefs.setBool('bool', true);
      await prefs.setDouble('double', 1.5);
      await prefs.setInt('int', 42);
      await prefs.setString('string', 'value');
      await prefs.setStringList('list', ['a', 'b']);

      expect(await prefs.getBool('bool'), isTrue);
      expect(await prefs.getDouble('double'), 1.5);
      expect(await prefs.getInt('int'), 42);
      expect(await prefs.getString('string'), 'value');
      expect(await prefs.getStringList('list'), ['a', 'b']);
    });

    test('clear respects allow list', () async {
      final prefs = MemorySharedPreferences();
      await prefs.setInt('keep', 1);
      await prefs.setInt('drop', 2);

      await prefs.clear(allowList: {'keep'});
      expect(await prefs.containsKey('keep'), isTrue);
      expect(await prefs.containsKey('drop'), isFalse);
    });

    test('getAll filters by allow list', () async {
      final prefs = MemorySharedPreferences();
      await prefs.setInt('keep', 1);
      await prefs.setInt('drop', 2);

      final filtered = await prefs.getAll(allowList: {'keep'});
      expect(filtered.keys, ['keep']);
    });
  });

  test('FakeDeviceInfo exposes deterministic info map', () async {
    final device = FakeDeviceInfo('device-123');
    final info = device.info;
    expect(info['deviceId'], 'device-123');

    final extracted = await device.extractInformation();
    expect(extracted['deviceId'], 'device-123');

    final appInfo = await device.appInfo();
    expect(appInfo['appName'], 'integration-cli');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/database/daos/contact_dao.dart';
import 'package:libmsgr/src/database/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('ContactDao', () {
    late DatabaseService databaseService;
    late ContactDao dao;

    setUp(() async {
      databaseService = DatabaseService();
      await databaseService.initialize();
      dao = ContactDao(databaseService.instance);
    });

    tearDown(() async {
      final path = databaseService.instance.path;
      await databaseService.instance.close();
      await databaseFactory.deleteDatabase(path);
    });

    Profile _profile(String id, {String? username}) {
      return Profile(
        id: id,
        uid: 'uid-$id',
        username: username ?? 'user-$id',
        firstName: 'First$id',
        lastName: 'Last$id',
        status: 'online',
        avatarUrl: null,
        settings: const {'theme': 'dark'},
        roles: const [],
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 2),
      );
    }

    test('persists and loads contacts', () async {
      final contact = _profile('1');

      await dao.upsertContacts('team-a', [contact]);

      final stored = await dao.getContacts('team-a');

      expect(stored, hasLength(1));
      expect(stored.single.id, contact.id);
      expect(stored.single.settings?['theme'], 'dark');
    });

    test('filters by team and orders alphabetically', () async {
      final alice = _profile('1', username: 'alice');
      final bob = _profile('2', username: 'bob');
      final charlie = _profile('3', username: 'charlie');

      await dao.upsertContacts('team-a', [charlie, alice, bob]);
      await dao.upsertContacts('team-b', [_profile('4', username: 'zoe')]);

      final stored = await dao.getContacts('team-a');

      expect(stored.map((c) => c.username), ['alice', 'bob', 'charlie']);
    });

    test('deletes contacts by id', () async {
      final contact = _profile('1');

      await dao.upsertContacts('team-a', [contact]);
      await dao.deleteContacts('team-a', ['1']);

      final stored = await dao.getContacts('team-a');
      expect(stored, isEmpty);
    });
  });
}

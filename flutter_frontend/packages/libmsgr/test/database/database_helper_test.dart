import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/database/database_helper.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseHelper Tests', () {
    late DatabaseHelper databaseHelper;

    setUp(() async {
      databaseHelper = DatabaseHelper();
      await databaseHelper.database;
    });

    tearDown(() async {
      final db = await databaseHelper.database;
      await db.close();
    });

    test('Insert and retrieve Conversation', () async {
      final conversation = Conversation(
        id: '1',
        topic: 'Test Topic',
        description: 'Test Description',
        members: ['member1', 'member2'],
        kIsSecret: false,
        createdAt: '2023-10-01',
      );

      await databaseHelper.insertConversation(conversation);
      final conversations = await databaseHelper.conversations();

      expect(conversations.length, 1);
      expect(conversations.first.id, conversation.id);
    });

    test('Insert and retrieve Room', () async {
      final room = Room(
        id: '1',
        name: 'Test Room',
        topic: 'Test Topic',
        description: 'Test Description',
        members: ['member1', 'member2'],
        kIsSecret: false,
        createdAt: '2023-10-01',
        updatedAt: '2023-10-01',
        metadata: {'felt': 'Test Metadata'},
      );

      await databaseHelper.insertRoom(room);
      final rooms = await databaseHelper.rooms();

      expect(rooms.length, 1);
      expect(rooms.first.id, room.id);
    });

    test('Insert and retrieve Message', () async {
      final message = MMessage(
        id: '1',
        content: 'Test Content',
        fromProfileID: 'profile1',
        conversationID: 'conversation1',
        roomID: 'room1',
        createdAt: '2023-10-01',
        updatedAt: '2023-10-01',
        kIsSystemMsg: false,
        inReplyToMsgID: 'msg1',
      );

      await databaseHelper.insertMessage(message);
      final messages = await databaseHelper.messages();

      expect(messages.length, 1);
      expect(messages.first.id, message.id);
    });

    test('Insert and retrieve Profile', () async {
      final profile = Profile(
        id: '1',
        uid: 'uuuuuuuuuuiiiiiiiddddd',
        username: 'testuser',
        firstName: 'Test',
        lastName: 'User',
        status: 'Active',
        insertedAt: '2023-10-01',
        avatarUrl: 'http://example.com/avatar.png',
        settings: {'property': 'Test Settings'},
        roles: [
          {'name': 'test', 'id': '1'}
        ],
      );

      await databaseHelper.insertProfile(profile);
      final profiles = await databaseHelper.profiles();

      expect(profiles.length, 1);
      expect(profiles.first.id, profile.id);
    });

    test('Insert and retrieve Device', () async {
      final algorithm1 = Ed25519();
      final signKeyPair = await algorithm1.newKeyPair();
      final algorithm2 = X25519();
      final dhKeyPair = await algorithm2.newKeyPair();
      final device = Device(
        signingKeyPair: signKeyPair,
        dhKeyPair: dhKeyPair,
        deviceId: 'device1',
      );

      await databaseHelper.insertDevice(device);
      final devices = await databaseHelper.devices();

      expect(devices.length, 1);
      expect(devices.first.deviceId, device.deviceId);
    });

    test('Insert and retrieve Team', () async {
      final team = Team(
        id: '1',
        name: 'Test Team',
        description: 'Test Description',
        creatorUid: 'creator1',
        createdAt: '2023-10-01',
      );

      await databaseHelper.insertTeam(team);
      final teams = await databaseHelper.teams();

      expect(teams.length, 1);
      expect(teams.first.id, team.id);
    });
  });
}

import 'package:libmsgr/libmsgr.dart';
import 'package:logging/logging.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  final Logger _log = Logger('DatabaseHelper');
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'app_database.db');
    _log.info('Database path: $path');
    return openDatabase(
      path,
      password: 'kake',
      onCreate: (db, version) {
        db.execute(
          'CREATE TABLE conversations(id TEXT PRIMARY KEY, topic TEXT, description TEXT, members TEXT, is_secret INTEGER, inserted_at TEXT)',
        );
        db.execute(
          'CREATE TABLE rooms(id TEXT PRIMARY KEY, name TEXT, topic TEXT, description TEXT, members TEXT, is_secret INTEGER, inserted_at TEXT, updated_at TEXT, metadata TEXT)',
        );
        db.execute(
          'CREATE TABLE messages(id TEXT PRIMARY KEY, content TEXT, profile_id TEXT, conversation_id TEXT, room_id TEXT, inserted_at TEXT, updated_at TEXT, is_system_msg INTEGER, in_reply_to_msg_id TEXT)',
        );
        db.execute(
          'CREATE TABLE profiles(id TEXT PRIMARY KEY, username TEXT, first_name TEXT, last_name TEXT, status_name TEXT, inserted_at TEXT, avatar_url TEXT, settings TEXT, roles TEXT)',
        );
        db.execute(
          'CREATE TABLE teams(id TEXT PRIMARY KEY, name TEXT, description TEXT, creator_uid TEXT, inserted_at TEXT)',
        );
        db.execute(
          'CREATE TABLE devices(id TEXT PRIMARY KEY, signing_key_pair TEXT, dh_key_pair TEXT, device_id TEXT)',
        );
      },
      version: 1,
    );
  }

  Future<void> insertConversation(Conversation conversation) async {
    final db = await database;
    await db.insert(
      'conversations',
      conversation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertRoom(Room room) async {
    final db = await database;
    await db.insert(
      'rooms',
      room.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertMessage(MMessage message) async {
    final db = await database;
    await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertProfile(Profile profile) async {
    final db = await database;
    await db.insert(
      'profiles',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertDevice(Device device) async {
    final db = await database;
    await db.insert(
      'devices',
      device.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertTeam(Team team) async {
    final db = await database;
    await db.insert(
      'teams',
      team.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Conversation>> conversations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('conversations');
    return List.generate(maps.length, (i) {
      return Conversation.fromMap(maps[i]);
    });
  }

  Future<List<Room>> rooms() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('rooms');
    return List.generate(maps.length, (i) {
      return Room.fromMap(maps[i]);
    });
  }

  Future<List<MMessage>> messages() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('messages');
    return List.generate(maps.length, (i) {
      return MMessage.fromMap(maps[i]);
    });
  }

  Future<List<Profile>> profiles() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('profiles');
    return List.generate(maps.length, (i) {
      return Profile.fromMap(maps[i]);
    });
  }

  Future<List<Device>> devices() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('devices');

    // Use Future.wait to handle asynchronous fromMap calls
    return Future.wait(maps.map((map) => Device.fromMap(map)).toList());
  }

  Future<List<Team>> teams() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('teams');
    return List.generate(maps.length, (i) {
      return Team.fromMap(maps[i]);
    });
  }
}

import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/database/constants.dart';
import 'package:libmsgr/src/database/helpers.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class MessageDao {
  MessageDao(this._db);

  final Database _db;

  Future<void> upsertMessages(
    String teamName,
    Iterable<MMessage> messages,
  ) async {
    if (messages.isEmpty) {
      return;
    }

    final batch = _db.batch();
    for (final message in messages) {
      batch.insert(
        messagesTable,
        _toDbMap(teamName, message),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> deleteMessages(String teamName, Iterable<String> ids) async {
    if (ids.isEmpty) {
      return;
    }

    final batch = _db.batch();
    for (final id in ids) {
      batch.delete(
        messagesTable,
        where: 'id = ? AND team_name = ?',
        whereArgs: [id, teamName],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<MMessage>> getMessagesForTeam(String teamName) async {
    final rows = await _db.query(
      messagesTable,
      where: 'team_name = ?',
      whereArgs: [teamName],
      orderBy: 'inserted_at ASC',
    );

    return rows.map(_fromDbMap).toList(growable: false);
  }

  Future<List<MMessage>> getMessagesForConversation(
    String teamName,
    String conversationId,
  ) async {
    final rows = await _db.query(
      messagesTable,
      where: 'team_name = ? AND conversation_id = ?',
      whereArgs: [teamName, conversationId],
      orderBy: 'inserted_at ASC',
    );

    return rows.map(_fromDbMap).toList(growable: false);
  }

  Future<List<MMessage>> getMessagesForRoom(
    String teamName,
    String roomId,
  ) async {
    final rows = await _db.query(
      messagesTable,
      where: 'team_name = ? AND room_id = ?',
      whereArgs: [teamName, roomId],
      orderBy: 'inserted_at ASC',
    );

    return rows.map(_fromDbMap).toList(growable: false);
  }

  Map<String, Object?> _toDbMap(String teamName, MMessage message) {
    return <String, Object?>{
      'id': message.id,
      'team_name': teamName,
      'content': message.content,
      'profile_id': message.fromProfileID,
      'conversation_id': message.conversationID,
      'room_id': message.roomID,
      'inserted_at': message.createdAt.toIso8601String(),
      'updated_at': message.updatedAt.toIso8601String(),
      'is_system_msg': boolToInt(message.kIsSystemMsg),
      'in_reply_to_id': message.inReplyToMsgID,
      'is_server_ack': boolToInt(message.isServerAck),
      'is_msg_read': boolToInt(message.isMsgRead),
    };
  }

  MMessage _fromDbMap(Map<String, Object?> map) {
    return MMessage.raw(
      id: map['id']! as String,
      fromProfileID: map['profile_id']! as String,
      content: map['content']! as String,
      conversationID: map['conversation_id'] as String?,
      roomID: map['room_id'] as String?,
      createdAt: DateTime.parse(map['inserted_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
      kIsSystemMsg: intToBool(map['is_system_msg']! as int),
      inReplyToMsgID: map['in_reply_to_id'] as String?,
      isServerAck: intToBool(map['is_server_ack']! as int),
      isMsgRead: intToBool(map['is_msg_read']! as int),
    );
  }
}

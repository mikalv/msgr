import 'dart:convert';

import 'package:libmsgr/src/database/constants.dart';
import 'package:libmsgr/src/models/outgoing_message.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/storage/storage_interface.dart';

class OutgoingMessageDao {
  const OutgoingMessageDao(this._db);

  final DatabaseConnection _db;

  Future<void> enqueue(String teamName, OutgoingMessage entry) async {
    await _db.insert(
      outgoingMessagesTable,
      entry.toDbMap(teamName),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markAttempt(
    String teamName,
    String messageId, {
    required DateTime attemptedAt,
    required int attemptCount,
    MMessage? message,
  }) async {
    await _db.update(
      outgoingMessagesTable,
      <String, Object?>{
        'last_attempt_at': attemptedAt.toIso8601String(),
        'attempt_count': attemptCount,
        if (message != null) 'payload': jsonEncode(message.toMap()),
      },
      where: 'message_id = ? AND team_name = ?',
      whereArgs: [messageId, teamName],
    );
  }

  Future<void> delete(String teamName, String messageId) async {
    await _db.delete(
      outgoingMessagesTable,
      where: 'message_id = ? AND team_name = ?',
      whereArgs: [messageId, teamName],
    );
  }

  Future<List<OutgoingMessage>> getPending(String teamName) async {
    final rows = await _db.query(
      outgoingMessagesTable,
      where: 'team_name = ?',
      whereArgs: [teamName],
      orderBy: 'last_attempt_at IS NOT NULL, last_attempt_at ASC',
    );

    return rows.map(OutgoingMessage.fromDbMap).toList(growable: false);
  }
}

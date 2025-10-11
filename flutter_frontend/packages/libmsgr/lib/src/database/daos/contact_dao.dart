import 'dart:convert';

import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/database/constants.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class ContactDao {
  ContactDao(this._db);

  final Database _db;

  Future<void> upsertContacts(
    String teamName,
    Iterable<Profile> contacts,
  ) async {
    if (contacts.isEmpty) {
      return;
    }

    final batch = _db.batch();
    for (final contact in contacts) {
      batch.insert(
        contactsTable,
        _toDbMap(teamName, contact),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> deleteContacts(String teamName, Iterable<String> ids) async {
    if (ids.isEmpty) {
      return;
    }

    final batch = _db.batch();
    for (final id in ids) {
      batch.delete(
        contactsTable,
        where: 'id = ? AND team_name = ?',
        whereArgs: [id, teamName],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<Profile>> getContacts(String teamName) async {
    final rows = await _db.query(
      contactsTable,
      where: 'team_name = ?',
      whereArgs: [teamName],
      orderBy: 'username COLLATE NOCASE ASC',
    );

    return rows.map(_fromDbMap).toList(growable: false);
  }

  Map<String, Object?> _toDbMap(String teamName, Profile contact) {
    return <String, Object?>{
      'id': contact.id,
      'team_name': teamName,
      'uid': contact.uid,
      'username': contact.username,
      'first_name': contact.firstName,
      'last_name': contact.lastName,
      'status': contact.status,
      'avatar_url': contact.avatarUrl,
      'settings': contact.settings == null ? null : jsonEncode(contact.settings),
      'roles': jsonEncode(contact.roles),
      'inserted_at': contact.createdAt.toIso8601String(),
      'updated_at': contact.updatedAt.toIso8601String(),
    };
  }

  Profile _fromDbMap(Map<String, Object?> map) {
    final settingsJson = map['settings'] as String?;
    final Map<String, dynamic>? settings = settingsJson == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(settingsJson) as Map);

    final rolesJson = map['roles'] as String?;
    final List<dynamic> roles = rolesJson == null
        ? <dynamic>[]
        : List<dynamic>.from(jsonDecode(rolesJson) as List);

    return Profile(
      id: map['id']! as String,
      uid: map['uid']! as String,
      username: map['username']! as String,
      firstName: map['first_name'] as String?,
      lastName: map['last_name'] as String?,
      status: map['status'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      settings: settings,
      roles: roles,
      createdAt: DateTime.parse(map['inserted_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
    );
  }
}

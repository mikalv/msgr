// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:libmsgr/src/models/base.dart';
import 'package:meta/meta.dart';

@immutable
class Team extends BaseModel {
  final String name;
  final String description;
  final String creatorUid;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> members;

  Team.raw(
      {super.id,
      required this.name,
      required this.description,
      required this.creatorUid,
      required this.createdAt,
      required this.updatedAt,
      this.members = const []});

  factory Team({id, name, description, creatorUid}) {
    return Team.raw(
        name: name,
        description: description,
        creatorUid: creatorUid,
        updatedAt: DateTime.now(),
        createdAt: DateTime.now());
  }

  @override
  bool operator ==(other) =>
      identical(this, other) ||
      other is Team &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          creatorUid == other.creatorUid;

  @override
  int get hashCode =>
      super.hashCode ^
      id.hashCode ^
      name.hashCode ^
      description.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      creatorUid.hashCode;

  factory Team.fromJson(dynamic json) {
    return switch (json) {
      {
        'id': String id,
        'name': String name,
        'description': String description,
        'creator_uid': String creatorUid,
        'inserted_at': String createdAt,
        'updated_at': String updatedAt,
        'members': List<dynamic> members
      } =>
        Team.raw(
          id: id,
          name: name,
          description: description,
          creatorUid: creatorUid,
          createdAt: DateTime.parse(createdAt),
          updatedAt: DateTime.parse(updatedAt),
          members: members.cast<String>(),
        ),
      _ => throw const FormatException('Failed to load team.'),
    };
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'creator_uid': creatorUid,
        'inserted_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'members': members
      };

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'creatorUid': creatorUid,
      'createdAt': createdAt,
      'members': members
    };
  }

  factory Team.fromMap(Map<String, dynamic> map) {
    return Team.raw(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      creatorUid: map['creatorUid'],
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
      members: map['members'] ?? [],
    );
  }

  @override
  String toString() {
    return 'Team{id: $id, name: $name}';
  }

  Team copyWith({
    String? id,
    String? name,
    String? description,
    String? creatorUid,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<dynamic>? members,
  }) {
    return Team.raw(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      creatorUid: creatorUid ?? this.creatorUid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      members: (members as List<String>) ?? this.members,
    );
  }
}

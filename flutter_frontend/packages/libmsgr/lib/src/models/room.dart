// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/models/base.dart';
import 'package:meta/meta.dart';

/// Represents a chat room in the messaging application.
///
/// A `Room` is a container for messages and participants. It extends the
/// `BaseModel` class, inheriting common model properties and methods.
///
/// This class is used to manage and store information about a chat room,
/// including its participants, messages, and metadata.
@immutable
class Room extends BaseModel {
  final String name;
  final String? topic;
  final String description;
  final List<dynamic> members;
  final bool kIsSecret;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  final List<MMessage> cachedMessages = [];

  String get formattedName => '#$name'.toLowerCase();

  Room.raw(
      {super.id,
      required this.name,
      required this.topic,
      required this.description,
      required this.members,
      required this.kIsSecret,
      required this.createdAt,
      required this.updatedAt,
      required this.metadata});

  @override
  bool operator ==(other) =>
      identical(this, other) ||
      other is Room &&
          id == other.id &&
          name == other.name &&
          topic == other.topic &&
          description == other.description &&
          members == other.members &&
          kIsSecret == other.kIsSecret &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          metadata == other.metadata;

  @override
  int get hashCode =>
      super.hashCode ^
      id.hashCode ^
      name.hashCode ^
      topic.hashCode ^
      description.hashCode ^
      members.hashCode ^
      kIsSecret.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      metadata.hashCode;

  factory Room({name, topic, description, members, kIsSecret, metadata}) {
    return Room.raw(
        name: name,
        topic: topic,
        description: description,
        members: members,
        kIsSecret: kIsSecret,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: metadata);
  }

  factory Room.fromJson(dynamic json) {
    /*return switch (json) {
      {
        'id': String id,
        'name': String name,
        'topic': String topic,
        'description': String description,
        'is_secret': bool isSecret,
        'inserted_at': String createdAt,
        'updated_at': String updatedAt,
        'members': List<dynamic> members,
        'metadata': Map<String, dynamic> metadata
      } =>
        Room(
            id: id,
            topic: topic,
            name: name,
            description: description,
            members: members,
            createdAt: createdAt,
            updatedAt: updatedAt,
            kIsSecret: isSecret,
            metadata: metadata),
      _ => throw const FormatException('Failed to load room.'),
    };*/
    return Room.raw(
        id: json['id'],
        description: json['description'],
        kIsSecret: json['is_secret'] as bool,
        members: json['members'],
        metadata: json['metadata'],
        name: json['name'],
        topic: json['topic'],
        createdAt: DateTime.parse(json['inserted_at']),
        updatedAt: DateTime.parse(json['updated_at']));
  }

  factory Room.fromMap(Map<String, dynamic> map) {
    return Room.raw(
        id: map['id'],
        name: map['name'],
        topic: map['topic'],
        description: map['description'],
        members: map['members'],
        kIsSecret: map['is_secret'],
        createdAt: map['inserted_at'],
        updatedAt: map['updated_at'],
        metadata: map['metadata']);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'topic': topic,
        'description': description,
        'is_secret': kIsSecret,
        'inserted_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'members': members,
        'metadata': metadata
      };

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'topic': topic,
      'description': description,
      'is_secret': kIsSecret,
      'inserted_at': createdAt,
      'updated_at': updatedAt,
      'members': members,
      'metadata': metadata
    };
  }

  @override
  String toString() {
    return 'Room{ID: $id, name: $name, topic: '
        '$topic, description: $description, kIsSecret: '
        '$kIsSecret, members: ${members.toString()}}';
  }

  Room copyWith({
    String? id,
    String? name,
    String? topic,
    String? description,
    List<dynamic>? members,
    bool? kIsSecret,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Room.raw(
      id: id ?? this.id,
      name: name ?? this.name,
      topic: topic ?? this.topic,
      description: description ?? this.description,
      members: members ?? this.members,
      kIsSecret: kIsSecret ?? this.kIsSecret,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

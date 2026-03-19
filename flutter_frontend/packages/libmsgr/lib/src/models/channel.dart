// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/models/base.dart';
import 'package:meta/meta.dart';

/// Represents a chat channel in the messaging application.
///
/// A `Channel` is a container for messages and participants. It extends the
/// `BaseModel` class, inheriting common model properties and methods.
///
/// This class is used to manage and store information about a chat channel,
/// including its participants, messages, and metadata.
@immutable
class Channel extends BaseModel {
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

  Channel.raw(
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
      other is Channel &&
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

  factory Channel({name, topic, description, members, kIsSecret, metadata}) {
    return Channel.raw(
        name: name,
        topic: topic,
        description: description,
        members: members,
        kIsSecret: kIsSecret,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: metadata);
  }

  factory Channel.fromJson(dynamic json) {
    return Channel.raw(
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

  factory Channel.fromMap(Map<String, dynamic> map) {
    return Channel.raw(
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
    return 'Channel{ID: $id, name: $name, topic: '
        '$topic, description: $description, kIsSecret: '
        '$kIsSecret, members: ${members.toString()}}';
  }

  Channel copyWith({
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
    return Channel.raw(
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

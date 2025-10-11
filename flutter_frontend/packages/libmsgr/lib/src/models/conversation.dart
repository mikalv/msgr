// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/models/base.dart';
import 'package:meta/meta.dart';

/// Represents a conversation model that extends the [BaseModel].
/// This class is used to define the structure and behavior of a conversation
/// within the application.
@immutable
class Conversation extends BaseModel {
  final String topic;
  final String description;
  final List<String> members;
  final bool kIsSecret;
  final DateTime createdAt;
  final DateTime updatedAt;

  final List<MMessage> cachedMessages = [];

  String conversationName(String teamName) {
    final ProfileRepository pr =
        LibMsgr().repositoryFactory.getRepositories(teamName).profileRepository;
    String name = '';
    for (var pID in members) {
      final Profile p = pr.fetchByID(pID);
      name += '${p.username}, ';
    }
    return name;
  }

  Conversation.raw(
      {super.id,
      required this.topic,
      required this.description,
      required this.members,
      required this.kIsSecret,
      required this.createdAt,
      required this.updatedAt});

  @override
  bool operator ==(other) =>
      identical(this, other) ||
      other is Conversation &&
          id == other.id &&
          topic == other.topic &&
          description == other.description &&
          members == other.members &&
          kIsSecret == other.kIsSecret &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      super.hashCode ^
      id.hashCode ^
      topic.hashCode ^
      description.hashCode ^
      members.hashCode ^
      kIsSecret.hashCode ^
      createdAt.hashCode;

  factory Conversation({topic, description, members, kIsSecret}) {
    return Conversation.raw(
        topic: topic,
        description: description,
        members: members,
        kIsSecret: kIsSecret,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now());
  }

  factory Conversation.fromJson(dynamic json) {
    if (json == null) {
      return Conversation.raw(
          id: 'none',
          topic: 'invalid',
          description: 'invalid, serialized from null',
          members: [],
          kIsSecret: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now());
    }
    return switch (json) {
      {
        'id': String id,
        'topic': String topic,
        'description': String description,
        'is_secret': bool isSecret,
        'inserted_at': String createdAt,
        'updated_at': String updatedAt,
        'members': List<String> members,
      } =>
        Conversation.raw(
            id: id,
            topic: topic,
            description: description,
            members: members,
            createdAt: DateTime.parse(createdAt),
            updatedAt: DateTime.parse(updatedAt),
            kIsSecret: isSecret),
      _ => throw const FormatException('Failed to load conversation.'),
    };
  }

  // Convert a Map into a Conversation
  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation.raw(
      id: map['id'],
      topic: map['topic'],
      description: map['description'],
      members: map['members'],
      kIsSecret: map['is_secret'],
      createdAt: map['inserted_at'],
      updatedAt: map['updated_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic': topic,
        'description': description,
        'is_secret': kIsSecret,
        'inserted_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'members': members
      };

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'topic': topic,
      'description': description,
      'is_secret': kIsSecret,
      'inserted_at': createdAt,
      'updated_at': updatedAt,
      'members': members
    };
  }

  @override
  String toString() {
    return 'Conversation{ID: $id, topic: $topic, description: $description, members: ${members.toString()}, kIsSecret: $kIsSecret}';
  }

  Conversation copyWith({
    String? id,
    String? topic,
    String? description,
    List<String>? members,
    bool? kIsSecret,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Conversation.raw(
      id: id ?? this.id,
      topic: topic ?? this.topic,
      description: description ?? this.description,
      members: members ?? this.members,
      kIsSecret: kIsSecret ?? this.kIsSecret,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

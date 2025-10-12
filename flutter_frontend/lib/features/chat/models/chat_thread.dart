import 'package:equatable/equatable.dart';

enum ChatThreadKind { direct, group, channel }

enum ChatStructureType { family, business, friends, project, other }

enum ChatVisibility { private, team }

class ChatThread extends Equatable {
  const ChatThread({
    required this.id,
    required this.participantNames,
    required this.kind,
    this.topic,
    this.structureType,
    this.visibility = ChatVisibility.private,
  });

  final String id;
  final List<String> participantNames;
  final ChatThreadKind kind;
  final String? topic;
  final ChatStructureType? structureType;
  final ChatVisibility visibility;

  String get displayName {
    final topicValue = topic?.trim();
    if (topicValue != null && topicValue.isNotEmpty) {
      return topicValue;
    }

    if (participantNames.isNotEmpty) {
      return participantNames.join(', ');
    }

    switch (kind) {
      case ChatThreadKind.channel:
        return '#kanal';
      case ChatThreadKind.group:
        return 'Gruppe';
      case ChatThreadKind.direct:
        return 'Direkte';
    }
  }

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    final participants = json['participants'] as List<dynamic>? ?? [];
    final names = participants
        .map((raw) => raw['profile']?['name'] as String? ?? 'Ukjent')
        .toList();

    return ChatThread(
      id: json['id'] as String,
      participantNames: names,
      kind: _parseKind(json['kind'] as String?),
      topic: json['topic'] as String?,
      structureType: _parseStructureType(json['structure_type'] as String?),
      visibility: _parseVisibility(json['visibility'] as String?),
    );
  }

  static ChatThreadKind _parseKind(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'group':
        return ChatThreadKind.group;
      case 'channel':
        return ChatThreadKind.channel;
      case 'direct':
      default:
        return ChatThreadKind.direct;
    }
  }

  String get kindName => kind.name;

  static ChatStructureType? _parseStructureType(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'family':
      case 'familie':
        return ChatStructureType.family;
      case 'business':
      case 'bedrift':
        return ChatStructureType.business;
      case 'friends':
      case 'venner':
      case 'vennegjeng':
        return ChatStructureType.friends;
      case 'project':
      case 'prosjekt':
        return ChatStructureType.project;
      case 'other':
        return ChatStructureType.other;
      default:
        return null;
    }
  }

  static ChatVisibility _parseVisibility(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'team':
      case 'public':
        return ChatVisibility.team;
      case 'private':
      case 'hidden':
      default:
        return ChatVisibility.private;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind.name,
      'topic': topic,
      'structure_type': structureType?.name,
      'visibility': visibility.name,
      'participants': [
        for (final name in participantNames)
          {
            'profile': {'name': name},
          }
      ],
    };
  }

  @override
  List<Object?> get props =>
      [id, participantNames, kind, topic, structureType, visibility];
}

import 'package:equatable/equatable.dart';

enum ChatThreadKind { direct, group, channel }

class ChatThread extends Equatable {
  const ChatThread({
    required this.id,
    required this.participantNames,
    required this.kind,
    this.topic,
  });

  final String id;
  final List<String> participantNames;
  final ChatThreadKind kind;
  final String? topic;

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

  @override
  List<Object?> get props => [id, participantNames, kind, topic];
}

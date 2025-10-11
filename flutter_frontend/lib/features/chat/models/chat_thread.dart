import 'package:equatable/equatable.dart';

class ChatThread extends Equatable {
  const ChatThread({
    required this.id,
    required this.participantNames,
  });

  final String id;
  final List<String> participantNames;

  String get displayName => participantNames.join(', ');

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    final participants = json['participants'] as List<dynamic>? ?? [];
    final names = participants
        .map((raw) => raw['profile']?['name'] as String? ?? 'Ukjent')
        .toList();
    return ChatThread(
      id: json['id'] as String,
      participantNames: names,
    );
  }

  @override
  List<Object?> get props => [id, participantNames];
}

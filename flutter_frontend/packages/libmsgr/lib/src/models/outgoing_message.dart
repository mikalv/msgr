import 'dart:convert';

import 'package:libmsgr/libmsgr.dart';

/// A durable queue entry for messages waiting on server acknowledgement.
class OutgoingMessage {
  const OutgoingMessage({
    required this.message,
    required this.topic,
    this.lastAttemptAt,
    this.attemptCount = 0,
  });

  final MMessage message;
  final String topic;
  final DateTime? lastAttemptAt;
  final int attemptCount;

  Map<String, Object?> toDbMap(String teamName) {
    return <String, Object?>{
      'message_id': message.id,
      'team_name': teamName,
      'topic': topic,
      'payload': jsonEncode(message.toMap()),
      'last_attempt_at': lastAttemptAt?.toIso8601String(),
      'attempt_count': attemptCount,
    };
  }

  OutgoingMessage copyWith({
    MMessage? message,
    String? topic,
    DateTime? lastAttemptAt,
    int? attemptCount,
  }) {
    return OutgoingMessage(
      message: message ?? this.message,
      topic: topic ?? this.topic,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      attemptCount: attemptCount ?? this.attemptCount,
    );
  }

  static OutgoingMessage fromDbMap(Map<String, Object?> map) {
    final payload = jsonDecode(map['payload']! as String) as Map<String, dynamic>;

    return OutgoingMessage(
      message: MMessage.fromMap(payload),
      topic: map['topic']! as String,
      lastAttemptAt: map['last_attempt_at'] == null
          ? null
          : DateTime.parse(map['last_attempt_at']! as String),
      attemptCount: (map['attempt_count']! as num).toInt(),
    );
  }
}

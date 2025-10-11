import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.body,
    required this.profileId,
    required this.profileName,
    required this.profileMode,
    required this.status,
    required this.sentAt,
    required this.insertedAt,
    this.isLocal = false,
  });

  final String id;
  final String body;
  final String profileId;
  final String profileName;
  final String profileMode;
  final String status;
  final DateTime? sentAt;
  final DateTime? insertedAt;
  final bool isLocal;

  ChatMessage copyWith({
    String? id,
    String? body,
    String? profileId,
    String? profileName,
    String? profileMode,
    String? status,
    DateTime? sentAt,
    DateTime? insertedAt,
    bool? isLocal,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      body: body ?? this.body,
      profileId: profileId ?? this.profileId,
      profileName: profileName ?? this.profileName,
      profileMode: profileMode ?? this.profileMode,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
      insertedAt: insertedAt ?? this.insertedAt,
      isLocal: isLocal ?? this.isLocal,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>?;
    return ChatMessage(
      id: json['id'] as String,
      body: json['body'] as String,
      profileId: profile?['id'] as String? ?? '',
      profileName: profile?['name'] as String? ?? 'Ukjent',
      profileMode: profile?['mode'] as String? ?? 'private',
      status: json['status'] as String? ?? 'sent',
      sentAt: _parseDate(json['sent_at']),
      insertedAt: _parseDate(json['inserted_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'body': body,
      'profileId': profileId,
      'profileName': profileName,
      'profileMode': profileMode,
      'status': status,
      'sentAt': sentAt?.toIso8601String(),
      'insertedAt': insertedAt?.toIso8601String(),
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [
        id,
        body,
        profileId,
        profileName,
        profileMode,
        status,
        sentAt,
        insertedAt,
        isLocal,
      ];
}

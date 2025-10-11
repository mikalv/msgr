import 'package:msgr_messages/msgr_messages.dart';

class ChatMessage extends MsgrTextMessage {
  const ChatMessage({
    required super.id,
    required super.body,
    required super.profileId,
    required super.profileName,
    required super.profileMode,
    required super.status,
    required super.sentAt,
    required super.insertedAt,
    super.isLocal,
    super.theme,
  });

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
    MsgrMessageTheme? theme,
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
      theme: theme ?? this.theme,
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
      sentAt: MsgrMessage.parseTimestamp(json['sent_at']),
      insertedAt: MsgrMessage.parseTimestamp(json['inserted_at']),
      theme: json['theme'] is Map<String, dynamic>
          ? MsgrMessageTheme.fromMap(json['theme'] as Map<String, dynamic>)
          : MsgrMessageTheme.defaultTheme,
    );
  }

  Map<String, dynamic> toJson() {
    final map = super.toMap();
    return {
      'id': map['id'],
      'body': map['body'],
      'profileId': map['profileId'],
      'profileName': map['profileName'],
      'profileMode': map['profileMode'],
      'status': map['status'],
      'sentAt': map['sentAt'],
      'insertedAt': map['insertedAt'],
      'isLocal': map['isLocal'],
      'theme': map['theme'],
    };
  }
}

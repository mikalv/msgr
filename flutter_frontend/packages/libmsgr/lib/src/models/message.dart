// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:libmsgr/src/models/base.dart';
import 'package:meta/meta.dart';

/// Represents a message model in the application.
///
/// This class extends from `BaseModel` and is used to define the structure
/// and behavior of a message within the application. It includes various
/// properties and methods that pertain to a message's data and functionality.
@immutable
class MMessage extends BaseModel {
  final String fromProfileID;
  final String content;
  final String? conversationID;
  final String? roomID;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool kIsSystemMsg;
  final String? inReplyToMsgID;
  final bool isServerAck;
  final bool isMsgRead;

  bool get hasReactions => false;

  MMessage.raw(
      {required this.fromProfileID,
      required this.content,
      required this.createdAt,
      required this.updatedAt,
      this.conversationID,
      this.roomID,
      this.inReplyToMsgID,
      super.id = 'server-will-set-it',
      this.isServerAck = true,
      this.kIsSystemMsg = false,
      this.isMsgRead = false}) {
    if (conversationID == null && roomID == null) {
      throw ArgumentError('Either conversationID or roomID must be provided');
    }
  }

  factory MMessage({content, fromProfileID, conversationID, roomID}) {
    return MMessage.raw(
        fromProfileID: fromProfileID,
        content: content,
        conversationID: conversationID,
        roomID: roomID,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now());
  }

  @override
  bool operator ==(other) =>
      identical(this, other) ||
      other is MMessage &&
          id == other.id &&
          fromProfileID == other.fromProfileID &&
          content == other.content &&
          conversationID == other.conversationID &&
          roomID == other.roomID &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          kIsSystemMsg == other.kIsSystemMsg &&
          inReplyToMsgID == other.inReplyToMsgID &&
          isMsgRead == other.isMsgRead;

  @override
  int get hashCode =>
      super.hashCode ^
      id.hashCode ^
      fromProfileID.hashCode ^
      content.hashCode ^
      conversationID.hashCode ^
      roomID.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      kIsSystemMsg.hashCode ^
      inReplyToMsgID.hashCode ^
      isMsgRead.hashCode;

  factory MMessage.fromMap(Map<String, dynamic> map) {
    return MMessage.raw(
      id: map['id'],
      content: map['content'],
      fromProfileID: map['profile_id'],
      conversationID: map['conversation_id'],
      roomID: map['room_id'],
      createdAt: map['inserted_at'].runtimeType == DateTime
          ? map['inserted_at']
          : DateTime.parse(map['inserted_at']),
      updatedAt: map['updated_at'].runtimeType == DateTime
          ? map['updated_at']
          : DateTime.parse(map['updated_at']),
      kIsSystemMsg: map['is_system_msg'],
      inReplyToMsgID: map['in_reply_to_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'profile_id': fromProfileID,
      'conversation_id': conversationID,
      'room_id': roomID,
      'inserted_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_system_msg': kIsSystemMsg,
      'in_reply_to_id': inReplyToMsgID,
    };
  }

  factory MMessage.fromJson(dynamic json) {
    return switch (json) {
      {
        'msgid': String id,
        'profile_id': String? fromProfileID,
        'content': String content,
        'conversation_id': String? conversationID,
        'room_id': String? roomID,
        'inserted_at': String createdAt,
        'updated_at': String updatedAt,
        'is_system_msg': bool? kIsSystemMsg,
        'in_reply_to_id': String? replyToID
      } =>
        MMessage.raw(
            id: id,
            fromProfileID: fromProfileID ?? 'system',
            content: content,
            conversationID: conversationID,
            roomID: roomID,
            createdAt: DateTime.parse(createdAt),
            updatedAt: DateTime.parse(updatedAt),
            kIsSystemMsg: kIsSystemMsg ?? false,
            inReplyToMsgID: replyToID),
      _ => throw const FormatException('Failed to load message.'),
    };
  }

  Map<String, dynamic> toJson() => {
        'msgid': id,
        'profile_id': fromProfileID,
        'content': content,
        'conversation_id': conversationID,
        'room_id': roomID,
        'inserted_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_system_msg': kIsSystemMsg,
        'in_reply_to_id': inReplyToMsgID
      };

  @override
  String toString() {
    return 'Message{msgid: $id, isRead: $isMsgRead, fromProfileID: $fromProfileID '
        'conversationID: $conversationID roomID: $roomID '
        'content: $content, createdAt: $createdAt, '
        'updatedAt: $updatedAt, kIsSystemMsg: $kIsSystemMsg, '
        'inReplyToMsgID: $inReplyToMsgID}';
  }

  MMessage copyWith({
    String? id,
    String? fromProfileID,
    String? content,
    String? conversationID,
    String? roomID,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? kIsSystemMsg,
    String? inReplyToMsgID,
    bool? isServerAck,
    bool? isMsgRead,
  }) {
    return MMessage.raw(
      id: id ?? this.id,
      fromProfileID: fromProfileID ?? this.fromProfileID,
      content: content ?? this.content,
      conversationID: conversationID ?? this.conversationID,
      roomID: roomID ?? this.roomID,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      kIsSystemMsg: kIsSystemMsg ?? this.kIsSystemMsg,
      inReplyToMsgID: inReplyToMsgID ?? this.inReplyToMsgID,
      isServerAck: isServerAck ?? this.isServerAck,
      isMsgRead: isMsgRead ?? this.isMsgRead,
    );
  }
}

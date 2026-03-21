/// Shared domain models for the new Riverpod providers.
///
/// These will eventually be replaced by real models from libmsgr or generated
/// from the backend schema. For now they carry just enough data for the UI to
/// render the Slack-style shell with mock data.

enum ChannelKind { channel, dm, groupDm }

enum ChannelVisibility { public, private }

class SlackTeam {
  const SlackTeam({
    required this.id,
    required this.name,
    required this.slug,
    this.iconEmoji,
    this.domain,
  });

  final String id;
  final String name;
  final String slug;
  final String? iconEmoji;
  final String? domain;

  SlackTeam copyWith({
    String? id,
    String? name,
    String? slug,
    String? iconEmoji,
    String? domain,
  }) {
    return SlackTeam(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      domain: domain ?? this.domain,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlackTeam && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SlackTeam($slug)';
}

class SlackChannel {
  const SlackChannel({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
    this.kind = ChannelKind.channel,
    this.visibility = ChannelVisibility.public,
    this.topic,
    this.teamSlug,
  });

  final String id;
  final String name;
  final String slug;
  final String? icon;
  final ChannelKind kind;
  final ChannelVisibility visibility;
  final String? topic;
  final String? teamSlug;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlackChannel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SlackChannel(#$slug)';
}

/// Structured mention data stored alongside message content.
class MentionData {
  const MentionData({
    required this.profileId,
    required this.displayName,
    required this.offset,
    required this.length,
  });

  final String profileId;
  final String displayName;
  final int offset;
  final int length;

  factory MentionData.fromJson(Map<String, dynamic> json) {
    return MentionData(
      profileId: json['profile_id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      length: (json['length'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'profile_id': profileId,
        'display_name': displayName,
        'offset': offset,
        'length': length,
      };
}

class SlackMessage {
  const SlackMessage({
    required this.id,
    required this.channelId,
    required this.senderProfileId,
    required this.senderName,
    required this.content,
    required this.insertedAt,
    this.threadParentId,
    this.threadReplyCount = 0,
    this.mediaRefs = const [],
    this.editedAt,
    this.status = MessageStatus.sent,
    this.reactions = const [],
    this.mentions = const [],
    this.isSystem = false,
  });

  final String id;
  final String channelId;
  final String senderProfileId;
  final String senderName;
  final String content;
  final DateTime insertedAt;
  final String? threadParentId;
  final int threadReplyCount;
  final List<String> mediaRefs;
  final DateTime? editedAt;
  final MessageStatus status;
  final List<MessageReaction> reactions;
  final List<MentionData> mentions;
  final bool isSystem;

  bool get isThreadReply => threadParentId != null;
  bool get hasThreadReplies => threadReplyCount > 0;
  bool get hasMentions => mentions.isNotEmpty;

  SlackMessage copyWith({
    String? id,
    String? channelId,
    String? senderProfileId,
    String? senderName,
    String? content,
    DateTime? insertedAt,
    String? threadParentId,
    int? threadReplyCount,
    List<String>? mediaRefs,
    DateTime? editedAt,
    MessageStatus? status,
    List<MessageReaction>? reactions,
    List<MentionData>? mentions,
    bool? isSystem,
  }) {
    return SlackMessage(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      senderProfileId: senderProfileId ?? this.senderProfileId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      insertedAt: insertedAt ?? this.insertedAt,
      threadParentId: threadParentId ?? this.threadParentId,
      threadReplyCount: threadReplyCount ?? this.threadReplyCount,
      mediaRefs: mediaRefs ?? this.mediaRefs,
      editedAt: editedAt ?? this.editedAt,
      status: status ?? this.status,
      reactions: reactions ?? this.reactions,
      mentions: mentions ?? this.mentions,
      isSystem: isSystem ?? this.isSystem,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlackMessage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

enum MessageStatus { sending, sent, delivered, read, failed }

class MessageReaction {
  const MessageReaction({
    required this.emoji,
    required this.count,
    required this.profileIds,
    this.includesMe = false,
  });

  final String emoji;
  final int count;
  final List<String> profileIds;
  final bool includesMe;

  MessageReaction copyWith({
    String? emoji,
    int? count,
    List<String>? profileIds,
    bool? includesMe,
  }) {
    return MessageReaction(
      emoji: emoji ?? this.emoji,
      count: count ?? this.count,
      profileIds: profileIds ?? this.profileIds,
      includesMe: includesMe ?? this.includesMe,
    );
  }

  factory MessageReaction.fromJson(Map<String, dynamic> json, {String? currentProfileId}) {
    final ids = <String>[
      for (final entry in (json['profile_ids'] as List? ?? const []))
        if (entry is String) entry
    ];
    return MessageReaction(
      emoji: json['emoji'] as String? ?? '',
      count: json['count'] as int? ?? ids.length,
      profileIds: ids,
      includesMe: currentProfileId != null && ids.contains(currentProfileId),
    );
  }
}

class PresenceInfo {
  const PresenceInfo({
    required this.profileId,
    required this.status,
    this.lastSeenAt,
  });

  final String profileId;
  final PresenceStatus status;
  final DateTime? lastSeenAt;
}

enum PresenceStatus { online, away, offline }

class SlackProfile {
  const SlackProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.email,
    this.phone,
    this.role,
    this.accountId,
    this.insertedAt,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? email;
  final String? phone;
  final String? role;
  final String? accountId;
  final DateTime? insertedAt;

  factory SlackProfile.fromJson(Map<String, dynamic> json) {
    DateTime? insertedAt;
    final raw = json['inserted_at'];
    if (raw is String) {
      insertedAt = DateTime.tryParse(raw);
    }
    return SlackProfile(
      id: json['id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? json['name']?.toString() ?? '',
      avatarUrl: json['avatar_url'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String?,
      accountId: json['account_id']?.toString(),
      insertedAt: insertedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlackProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

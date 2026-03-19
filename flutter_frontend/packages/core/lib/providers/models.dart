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

class SlackMessage {
  const SlackMessage({
    required this.id,
    required this.channelId,
    required this.senderProfileId,
    required this.senderName,
    required this.content,
    required this.insertedAt,
    this.threadParentId,
    this.mediaRefs = const [],
    this.editedAt,
    this.status = MessageStatus.sent,
  });

  final String id;
  final String channelId;
  final String senderProfileId;
  final String senderName;
  final String content;
  final DateTime insertedAt;
  final String? threadParentId;
  final List<String> mediaRefs;
  final DateTime? editedAt;
  final MessageStatus status;

  bool get isThreadReply => threadParentId != null;

  SlackMessage copyWith({
    String? id,
    String? channelId,
    String? senderProfileId,
    String? senderName,
    String? content,
    DateTime? insertedAt,
    String? threadParentId,
    List<String>? mediaRefs,
    DateTime? editedAt,
    MessageStatus? status,
  }) {
    return SlackMessage(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      senderProfileId: senderProfileId ?? this.senderProfileId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      insertedAt: insertedAt ?? this.insertedAt,
      threadParentId: threadParentId ?? this.threadParentId,
      mediaRefs: mediaRefs ?? this.mediaRefs,
      editedAt: editedAt ?? this.editedAt,
      status: status ?? this.status,
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
    this.role,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? email;
  final String? role;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlackProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

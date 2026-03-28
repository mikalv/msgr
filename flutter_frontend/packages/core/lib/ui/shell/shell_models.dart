/// Data models for the app shell layout.
///
/// These are lightweight value classes used by the team rail, channel sidebar,
/// and DM list. They will eventually be replaced by real domain models once
/// the backend integration is wired up.

enum ChannelKind { public, private, announcement }

class TeamItem {
  const TeamItem({
    required this.id,
    required this.name,
    required this.slug,
    required this.iconEmoji,
    this.unreadCount = 0,
  });

  final String id;
  final String name;
  final String slug;
  final String iconEmoji;
  final int unreadCount;
}

class ChannelItem {
  const ChannelItem({
    required this.id,
    required this.name,
    required this.slug,
    required this.iconEmoji,
    required this.kind,
    this.unreadCount = 0,
    this.hasDraft = false,
    this.lastActivityAt,
    this.lastMessageSender,
    this.lastMessageText,
  });

  final String id;
  final String name;
  final String slug;
  final String iconEmoji;
  final ChannelKind kind;
  final int unreadCount;
  final bool hasDraft;
  final DateTime? lastActivityAt;
  final String? lastMessageSender;
  final String? lastMessageText;
}

class DmItem {
  const DmItem({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isOnline = false,
    this.unreadCount = 0,
    this.lastActivityAt,
    this.isSelf = false,
    this.lastMessageText,
    this.memberCount = 2,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final bool isOnline;
  final int unreadCount;
  final DateTime? lastActivityAt;
  final bool isSelf;
  final String? lastMessageText;
  final int memberCount;
}

import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'auth_state_provider.dart';
import 'channel_list_provider.dart';
import 'models.dart';
import 'msgr_client_provider.dart';
import 'realtime_provider.dart';
import 'team_list_provider.dart';

// ---------------------------------------------------------------------------
// ChannelMessages -- messages for the currently selected channel
// ---------------------------------------------------------------------------

class ChannelMessagesState {
  const ChannelMessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.cursor,
  });

  final List<MsgrMessage> messages;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;

  /// Cursor for pagination (ID of oldest loaded message).
  final String? cursor;

  ChannelMessagesState copyWith({
    List<MsgrMessage>? messages,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    String? cursor,
  }) {
    return ChannelMessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      cursor: cursor ?? this.cursor,
    );
  }
}

class ChannelMessagesNotifier extends StateNotifier<ChannelMessagesState> {
  ChannelMessagesNotifier(this._ref) : super(const ChannelMessagesState());

  final Ref _ref;
  static const _pageSize = 50;

  /// Fetch initial messages for a channel.
  Future<void> loadMessages(String channelId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final team = _ref.read(selectedTeamProvider);
      if (team == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final auth = _ref.read(simpleAuthProvider);
      final client = _ref.read(msgrApiProvider);
      final data = await client.getMessages(team.slug, channelId, limit: _pageSize);
      final messages = data
          .map((m) => parseMessageJson(m, channelId, currentProfileId: auth.profileId))
          .toList();

      state = state.copyWith(
        messages: messages,
        isLoading: false,
        hasMore: messages.length >= _pageSize,
        cursor: messages.isNotEmpty ? messages.first.id : null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  /// Refresh messages silently (for polling). Merges new messages without loading state.
  Future<void> refresh(String channelId) async {
    try {
      final team = _ref.read(selectedTeamProvider);
      if (team == null) return;

      final auth = _ref.read(simpleAuthProvider);
      final client = _ref.read(msgrApiProvider);
      final data = await client.getMessages(team.slug, channelId, limit: _pageSize);
      final fresh = data
          .map((m) => parseMessageJson(m, channelId, currentProfileId: auth.profileId))
          .toList();

      // Only update if there are new messages
      final existingIds = state.messages.map((m) => m.id).toSet();
      final hasNew = fresh.any((m) => !existingIds.contains(m.id));
      if (hasNew) {
        state = state.copyWith(messages: fresh);
      }
    } catch (_) {
      // Silent refresh -- don't show errors
    }
  }

  /// Load older messages (cursor pagination).
  Future<void> loadMore(String channelId) async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final team = _ref.read(selectedTeamProvider);
      if (team == null) {
        state = state.copyWith(isLoadingMore: false);
        return;
      }

      final auth = _ref.read(simpleAuthProvider);
      final client = _ref.read(msgrApiProvider);
      final data = await client.getMessages(
        team.slug,
        channelId,
        limit: _pageSize,
        before: state.cursor,
      );

      if (data.isEmpty) {
        state = state.copyWith(isLoadingMore: false, hasMore: false);
        return;
      }

      final messages = data
          .map((m) => parseMessageJson(m, channelId, currentProfileId: auth.profileId))
          .toList();

      state = state.copyWith(
        messages: [...messages, ...state.messages],
        isLoadingMore: false,
        hasMore: messages.length >= _pageSize,
        cursor: messages.isNotEmpty ? messages.first.id : state.cursor,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }

  /// Send a message to the channel.
  Future<void> sendMessage(
    String channelId,
    String content, {
    List<String>? mediaRefs,
    List<MentionData>? mentions,
    String? replyToId,
    ReplyToSnippet? replyTo,
  }) async {
    final auth = _ref.read(simpleAuthProvider);

    // Optimistic insert
    final tempId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = MsgrMessage(
      id: tempId,
      channelId: channelId,
      senderProfileId: auth.profileId ?? 'me',
      senderName: auth.displayName ?? auth.email ?? 'Deg',
      content: content,
      insertedAt: DateTime.now(),
      mediaRefs: mediaRefs ?? [],
      status: MessageStatus.sending,
      mentions: mentions ?? [],
      replyToId: replyToId,
      replyTo: replyTo,
    );

    state = state.copyWith(messages: [...state.messages, optimistic]);

    try {
      final team = _ref.read(selectedTeamProvider);
      if (team == null) throw Exception('No team selected');

      // Build content JSONB with mentions if present.
      final contentPayload = _buildContentPayload(content, mentions);

      // Try Phoenix Channel push first, fall back to REST.
      final realtime = _ref.read(realtimeProvider.notifier);
      final pushed = await realtime.sendMessageViaChannel(
        channelId,
        contentPayload,
        mediaRefs: mediaRefs,
      );

      String? serverId;
      if (!pushed) {
        // REST fallback
        final client = _ref.read(msgrApiProvider);
        final raw = await client.sendMessageRich(team.slug, channelId, contentPayload, replyToId: replyToId);
        final data = raw.containsKey('data') && raw['data'] is Map
            ? raw['data'] as Map<String, dynamic>
            : raw;
        serverId = data['id']?.toString();
      }

      // Replace optimistic message with confirmed status.
      // For channel push, the broadcast will arrive with the real ID;
      // for REST, we have the ID from the response.
      final sent = optimistic.copyWith(
        id: serverId ?? 'msg-${DateTime.now().microsecondsSinceEpoch}',
        status: MessageStatus.sent,
      );
      final updated =
          state.messages.map((m) => m.id == tempId ? sent : m).toList();
      state = state.copyWith(messages: updated);
    } catch (e) {
      // Mark as failed
      final updated = state.messages
          .map(
              (m) => m.id == tempId ? m.copyWith(status: MessageStatus.failed) : m)
          .toList();
      state = state.copyWith(messages: updated, error: e);
    }
  }

  /// Toggle a reaction on a message (optimistic update + server call).
  Future<void> toggleReaction(String messageId, String emoji) async {
    final auth = _ref.read(simpleAuthProvider);
    final myProfileId = auth.profileId ?? '';

    // Optimistic update
    final updated = state.messages.map((m) {
      if (m.id != messageId) return m;
      final reactions = List<MessageReaction>.from(m.reactions);
      final idx = reactions.indexWhere((r) => r.emoji == emoji);
      if (idx >= 0) {
        final r = reactions[idx];
        if (r.includesMe) {
          // Remove my reaction
          final newIds = r.profileIds.where((id) => id != myProfileId).toList();
          if (newIds.isEmpty) {
            reactions.removeAt(idx);
          } else {
            reactions[idx] = r.copyWith(
              count: r.count - 1,
              profileIds: newIds,
              includesMe: false,
            );
          }
        } else {
          // Add my reaction
          reactions[idx] = r.copyWith(
            count: r.count + 1,
            profileIds: [...r.profileIds, myProfileId],
            includesMe: true,
          );
        }
      } else {
        // New reaction
        reactions.add(MessageReaction(
          emoji: emoji,
          count: 1,
          profileIds: [myProfileId],
          includesMe: true,
        ));
      }
      return m.copyWith(reactions: reactions);
    }).toList();
    state = state.copyWith(messages: updated);

    // Send to server -- try WebSocket push first, fall back to REST
    try {
      final team = _ref.read(selectedTeamProvider);
      final channel = _ref.read(selectedChannelProvider);
      if (team == null || channel == null) return;

      final realtime = _ref.read(realtimeProvider.notifier);
      final pushed = await realtime.toggleReactionViaChannel(
        channel.id,
        messageId,
        emoji,
      );

      if (!pushed) {
        // REST fallback
        final client = _ref.read(msgrApiProvider);
        await client.toggleReaction(team.slug, channel.id, messageId, emoji);
      }
    } catch (_) {
      // Optimistic update stays -- server will reconcile on next fetch
    }
  }

  /// Update reactions for a specific message from a server event.
  void updateReactions(String messageId, List<MessageReaction> reactions) {
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;
    final updated = [...state.messages];
    updated[idx] = updated[idx].copyWith(reactions: reactions);
    state = state.copyWith(messages: updated);
  }

  /// Merge an incoming realtime message.
  void mergeIncoming(MsgrMessage message) {
    // Check for exact ID match first
    final existing = state.messages.indexWhere((m) => m.id == message.id);
    if (existing >= 0) {
      final updated = [...state.messages];
      updated[existing] = message;
      state = state.copyWith(messages: updated);
      return;
    }

    // Check if this replaces an optimistic (local-*) message with matching content
    final optimisticIdx = state.messages.indexWhere((m) =>
        m.id.startsWith('local-') &&
        m.content == message.content &&
        m.channelId == message.channelId);
    if (optimisticIdx >= 0) {
      final updated = [...state.messages];
      updated[optimisticIdx] = message;
      state = state.copyWith(messages: updated);
      return;
    }

    state = state.copyWith(messages: [...state.messages, message]);
  }

  void removeMessage(String messageId) {
    final updated = state.messages.where((m) => m.id != messageId).toList();
    state = state.copyWith(messages: updated);
  }

  void updateMessage(String messageId, {String? content, DateTime? editedAt}) {
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;

    final msg = state.messages[idx];
    final updated = msg.copyWith(
      content: content ?? msg.content,
      editedAt: editedAt,
    );
    final messages = [...state.messages];
    messages[idx] = updated;
    state = state.copyWith(messages: messages);
  }

  void clear() => state = const ChannelMessagesState();
}

final channelMessagesProvider =
    StateNotifierProvider<ChannelMessagesNotifier, ChannelMessagesState>((ref) {
  final notifier = ChannelMessagesNotifier(ref);

  // Auto-load messages when the selected channel changes.
  final selectedChannel = ref.watch(selectedChannelProvider);
  if (selectedChannel != null) {
    Future.microtask(() => notifier.loadMessages(selectedChannel.id));
  }

  return notifier;
});

/// Convenience: just the message list.
final messagesListProvider = Provider<List<MsgrMessage>>((ref) {
  return ref.watch(channelMessagesProvider).messages;
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Parse a message JSON map into a [MsgrMessage], including reactions.
MsgrMessage parseMessageJson(
  Map<String, dynamic> m,
  String channelId, {
  String? currentProfileId,
}) {
  final sender = m['sender_profile'] as Map<String, dynamic>? ??
      m['sender'] as Map<String, dynamic>? ??
      {};

  final rawReactions = m['reactions'];
  final reactions = <MessageReaction>[];
  if (rawReactions is List) {
    for (final r in rawReactions) {
      if (r is Map<String, dynamic>) {
        reactions.add(MessageReaction.fromJson(r, currentProfileId: currentProfileId));
      }
    }
  }

  // Detect system messages: no sender profile, or content has system: true
  final isSystem = _isSystemMessage(m['content'], sender);

  return MsgrMessage(
    id: m['id']?.toString() ?? '',
    channelId: channelId,
    senderProfileId: m['profile_id']?.toString() ??
        sender['id']?.toString() ??
        '',
    senderName: isSystem
        ? 'System'
        : (m['sender_name']?.toString() ??
            sender['display_name']?.toString() ??
            sender['name']?.toString() ??
            'Ukjent'),
    content: _extractContent(m['content']),
    insertedAt:
        DateTime.tryParse(m['inserted_at']?.toString() ?? '') ?? DateTime.now(),
    threadParentId: m['thread_parent_id'] as String?,
    mediaRefs:
        (m['media_refs'] as List?)?.map((r) => r.toString()).toList() ?? [],
    threadReplyCount: (m['thread_reply_count'] as num?)?.toInt() ?? 0,
    replyToId: m['reply_to_id'] as String?,
    replyTo: m['reply_to'] is Map<String, dynamic>
        ? ReplyToSnippet.fromJson(m['reply_to'] as Map<String, dynamic>)
        : null,
    pinned: m['pinned'] == true,
    status: MessageStatus.sent,
    reactions: reactions,
    mentions: _extractMentions(m['content']),
    isSystem: isSystem,
    senderAvatarUrl: sender['avatar_url'] as String?,
    senderEmail: sender['email'] as String?,
  );
}

/// Check if a message is a system message (no sender or content.system == true).
bool _isSystemMessage(dynamic content, Map<String, dynamic> sender) {
  if (sender.isEmpty || sender['id'] == null) return true;
  if (content is Map && content['system'] == true) return true;
  return false;
}

/// Extract text from content field -- handles both String and Map (JSONB).
String _extractContent(dynamic content) {
  if (content is String) return content;
  if (content is Map) return content['text']?.toString() ?? content.toString();
  return content?.toString() ?? '';
}

/// Extract mention data from content JSONB.
List<MentionData> _extractMentions(dynamic content) {
  if (content is! Map) return const [];
  final rawMentions = content['mentions'];
  if (rawMentions is! List) return const [];
  return rawMentions
      .whereType<Map<String, dynamic>>()
      .map((m) => MentionData.fromJson(m))
      .toList();
}

/// Build the content payload for sending. If mentions are present,
/// returns a Map with text + mentions; otherwise returns plain text string.
dynamic _buildContentPayload(String text, List<MentionData>? mentions) {
  if (mentions == null || mentions.isEmpty) return text;
  return {
    'text': text,
    'mentions': mentions.map((m) => m.toJson()).toList(),
  };
}

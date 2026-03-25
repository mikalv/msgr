import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'auth_state_provider.dart';
import 'channel_list_provider.dart';
import 'messages_provider.dart';
import 'models.dart';
import 'msgr_client_provider.dart';
import 'team_list_provider.dart';

// ---------------------------------------------------------------------------
// ThreadMessages -- replies for a specific parent message
// ---------------------------------------------------------------------------

class ThreadMessagesState {
  const ThreadMessagesState({
    this.parentMessageId,
    this.parentMessage,
    this.replies = const [],
    this.isLoading = false,
    this.error,
  });

  final String? parentMessageId;
  final MsgrMessage? parentMessage;
  final List<MsgrMessage> replies;
  final bool isLoading;
  final Object? error;

  bool get isOpen => parentMessageId != null;

  ThreadMessagesState copyWith({
    String? parentMessageId,
    MsgrMessage? parentMessage,
    List<MsgrMessage>? replies,
    bool? isLoading,
    Object? error,
  }) {
    return ThreadMessagesState(
      parentMessageId: parentMessageId ?? this.parentMessageId,
      parentMessage: parentMessage ?? this.parentMessage,
      replies: replies ?? this.replies,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ThreadMessagesNotifier extends StateNotifier<ThreadMessagesState> {
  ThreadMessagesNotifier(this._ref) : super(const ThreadMessagesState());

  final Ref _ref;

  /// Open a thread and load its replies from the API.
  Future<void> openThread(MsgrMessage parentMessage) async {
    state = ThreadMessagesState(
      parentMessageId: parentMessage.id,
      parentMessage: parentMessage,
      isLoading: true,
    );
    try {
      final team = _ref.read(selectedTeamProvider);
      final channel = _ref.read(selectedChannelProvider);
      if (team == null || channel == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final auth = _ref.read(simpleAuthProvider);
      final client = _ref.read(msgrApiProvider);
      final data = await client.getThread(
        team.slug,
        channel.id,
        parentMessage.id,
      );

      final parentJson = data['parent'] as Map<String, dynamic>?;
      final repliesJson = data['replies'] as List? ?? [];

      final parsedParent = parentJson != null
          ? parseMessageJson(parentJson, parentMessage.channelId,
              currentProfileId: auth.profileId)
          : parentMessage;

      final parsedReplies = repliesJson
          .whereType<Map<String, dynamic>>()
          .map((r) => parseMessageJson(r, parentMessage.channelId,
              currentProfileId: auth.profileId))
          .toList();

      state = state.copyWith(
        parentMessage: parsedParent,
        replies: parsedReplies,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  /// Post a reply in the thread via REST.
  Future<void> reply(String content) async {
    if (state.parentMessageId == null) return;

    final auth = _ref.read(simpleAuthProvider);
    final tempId = 'thread-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = MsgrMessage(
      id: tempId,
      channelId: state.parentMessage?.channelId ?? '',
      senderProfileId: auth.profileId ?? 'me',
      senderName: auth.displayName ?? auth.email ?? 'Deg',
      content: content,
      insertedAt: DateTime.now(),
      threadParentId: state.parentMessageId,
      status: MessageStatus.sending,
    );

    state = state.copyWith(replies: [...state.replies, optimistic]);

    try {
      final team = _ref.read(selectedTeamProvider);
      final channel = _ref.read(selectedChannelProvider);
      if (team == null || channel == null) {
        throw Exception('No team or channel selected');
      }

      final client = _ref.read(msgrApiProvider);
      final raw = await client.sendThreadReply(
        team.slug,
        channel.id,
        state.parentMessageId!,
        content,
      );

      final data = raw.containsKey('data') && raw['data'] is Map
          ? raw['data'] as Map<String, dynamic>
          : raw;
      final serverId = data['id']?.toString() ??
          'tr-${DateTime.now().microsecondsSinceEpoch}';

      final sent = optimistic.copyWith(
        id: serverId,
        status: MessageStatus.sent,
      );
      final updated =
          state.replies.map((r) => r.id == tempId ? sent : r).toList();
      state = state.copyWith(replies: updated);

      // Update the parent message's thread_reply_count in the channel messages
      _incrementParentReplyCount();
    } catch (e) {
      final updated = state.replies
          .map(
              (r) => r.id == tempId ? r.copyWith(status: MessageStatus.failed) : r)
          .toList();
      state = state.copyWith(replies: updated, error: e);
    }
  }

  /// Merge an incoming thread reply from WebSocket.
  void mergeIncomingReply(MsgrMessage reply) {
    if (reply.threadParentId != state.parentMessageId) return;

    // Check for duplicate
    final existing = state.replies.indexWhere((r) => r.id == reply.id);
    if (existing >= 0) {
      final updated = [...state.replies];
      updated[existing] = reply;
      state = state.copyWith(replies: updated);
      return;
    }

    state = state.copyWith(replies: [...state.replies, reply]);
  }

  void _incrementParentReplyCount() {
    final parentId = state.parentMessageId;
    if (parentId == null) return;

    final messagesNotifier = _ref.read(channelMessagesProvider.notifier);
    final messagesState = _ref.read(channelMessagesProvider);
    final idx = messagesState.messages.indexWhere((m) => m.id == parentId);
    if (idx >= 0) {
      final msg = messagesState.messages[idx];
      final updated = msg.copyWith(threadReplyCount: msg.threadReplyCount + 1);
      messagesNotifier.mergeIncoming(updated);
    }
  }

  void closeThread() => state = const ThreadMessagesState();
}

final threadMessagesProvider =
    StateNotifierProvider<ThreadMessagesNotifier, ThreadMessagesState>((ref) {
  return ThreadMessagesNotifier(ref);
});

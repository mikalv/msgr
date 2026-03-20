import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'mock_api_data.dart';
import 'models.dart';
import 'team_list_provider.dart';

// ---------------------------------------------------------------------------
// ThreadMessages — replies for a specific parent message
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
  final SlackMessage? parentMessage;
  final List<SlackMessage> replies;
  final bool isLoading;
  final Object? error;

  bool get isOpen => parentMessageId != null;

  ThreadMessagesState copyWith({
    String? parentMessageId,
    SlackMessage? parentMessage,
    List<SlackMessage>? replies,
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

  /// Open a thread and load its replies.
  Future<void> openThread(SlackMessage parentMessage) async {
    state = ThreadMessagesState(
      parentMessageId: parentMessage.id,
      parentMessage: parentMessage,
      isLoading: true,
    );
    try {
      // TODO: GET /api/teams/:slug/channels/:id/threads/:messageId
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final replies = mockThreadReplies[parentMessage.id] ?? [];
      state = state.copyWith(replies: replies, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  /// Post a reply in the thread.
  Future<void> reply(String content) async {
    if (state.parentMessageId == null) return;
    final tempId = 'thread-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = SlackMessage(
      id: tempId,
      channelId: state.parentMessage?.channelId ?? '',
      senderProfileId: 'me',
      senderName: 'Deg',
      content: content,
      insertedAt: DateTime.now(),
      threadParentId: state.parentMessageId,
      status: MessageStatus.sending,
    );

    state = state.copyWith(replies: [...state.replies, optimistic]);

    try {
      // TODO: POST /api/teams/:slug/channels/:id/messages/:id/thread
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final sent = optimistic.copyWith(
        id: 'tr-${DateTime.now().microsecondsSinceEpoch}',
        status: MessageStatus.sent,
      );
      final updated = state.replies
          .map((r) => r.id == tempId ? sent : r)
          .toList();
      state = state.copyWith(replies: updated);
    } catch (e) {
      final updated = state.replies
          .map((r) => r.id == tempId ? r.copyWith(status: MessageStatus.failed) : r)
          .toList();
      state = state.copyWith(replies: updated, error: e);
    }
  }

  void closeThread() => state = const ThreadMessagesState();
}

final threadMessagesProvider =
    StateNotifierProvider<ThreadMessagesNotifier, ThreadMessagesState>((ref) {
  return ThreadMessagesNotifier(ref);
});

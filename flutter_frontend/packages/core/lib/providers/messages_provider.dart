import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client_provider.dart';
import 'channel_list_provider.dart';
import 'mock_api_data.dart';
import 'models.dart';
import 'team_list_provider.dart';

// ---------------------------------------------------------------------------
// ChannelMessages — messages for the currently selected channel
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

  final List<SlackMessage> messages;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;

  /// Cursor for pagination (ID of oldest loaded message).
  final String? cursor;

  ChannelMessagesState copyWith({
    List<SlackMessage>? messages,
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
      // TODO: GET /api/teams/:slug/channels/:id/messages?limit=50
      // final team = _ref.read(selectedTeamProvider);
      // final client = _ref.read(apiClientProvider);
      // final response = await client.get(
      //   '/api/teams/${team?.slug}/channels/$channelId/messages',
      //   query: {'limit': '$_pageSize'},
      // );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final messages = mockSlackMessages[channelId] ?? [];
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

  /// Load older messages (cursor pagination).
  Future<void> loadMore(String channelId) async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      // TODO: GET /api/teams/:slug/channels/:id/messages?before=cursor&limit=50
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // Mock: no more messages
      state = state.copyWith(isLoadingMore: false, hasMore: false);
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }

  /// Send a message to the channel.
  Future<void> sendMessage(
    String channelId,
    String content, {
    List<String>? mediaRefs,
  }) async {
    // Optimistic insert
    final tempId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = SlackMessage(
      id: tempId,
      channelId: channelId,
      senderProfileId: 'me',
      senderName: 'Deg',
      content: content,
      insertedAt: DateTime.now(),
      mediaRefs: mediaRefs ?? [],
      status: MessageStatus.sending,
    );

    state = state.copyWith(messages: [...state.messages, optimistic]);

    try {
      // TODO: POST /api/teams/:slug/channels/:id/messages
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Replace optimistic message with "sent" version.
      final sent = optimistic.copyWith(
        id: 'msg-${DateTime.now().microsecondsSinceEpoch}',
        status: MessageStatus.sent,
      );
      final updated = state.messages
          .map((m) => m.id == tempId ? sent : m)
          .toList();
      state = state.copyWith(messages: updated);
    } catch (e) {
      // Mark as failed
      final updated = state.messages
          .map((m) => m.id == tempId ? m.copyWith(status: MessageStatus.failed) : m)
          .toList();
      state = state.copyWith(messages: updated, error: e);
    }
  }

  /// Merge an incoming realtime message.
  void mergeIncoming(SlackMessage message) {
    final existing = state.messages.indexWhere((m) => m.id == message.id);
    if (existing >= 0) {
      final updated = [...state.messages];
      updated[existing] = message;
      state = state.copyWith(messages: updated);
    } else {
      state = state.copyWith(messages: [...state.messages, message]);
    }
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
final messagesListProvider = Provider<List<SlackMessage>>((ref) {
  return ref.watch(channelMessagesProvider).messages;
});

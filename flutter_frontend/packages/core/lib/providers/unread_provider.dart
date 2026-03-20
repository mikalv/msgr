import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'mock_api_data.dart';
import 'team_list_provider.dart';

// ---------------------------------------------------------------------------
// UnreadCounts — unread message counts per channel
// ---------------------------------------------------------------------------

class UnreadCountsNotifier extends StateNotifier<Map<String, int>> {
  UnreadCountsNotifier(this._ref) : super({});

  final Ref _ref;

  /// Load initial unread counts for a team.
  void loadForTeam(String teamSlug) {
    // TODO: Receive unread counts from Phoenix channel or initial API response.
    // For now, use mock data.
    state = Map<String, int>.from(mockUnreadCounts);
  }

  /// Mark a channel as read (set count to 0).
  void markRead(String channelId) {
    if (!state.containsKey(channelId) || state[channelId] == 0) return;
    state = {...state, channelId: 0};
    // TODO: PUT /api/teams/:slug/channels/:id/read_cursor
  }

  /// Increment unread count for a channel (called when a realtime message
  /// arrives for a channel that is not currently being viewed).
  void increment(String channelId) {
    final current = state[channelId] ?? 0;
    state = {...state, channelId: current + 1};
  }

  /// Get unread count for a channel.
  int countFor(String channelId) => state[channelId] ?? 0;

  /// Total unread count across all channels (for team badge).
  int get totalUnread => state.values.fold(0, (a, b) => a + b);

  void clear() => state = {};
}

final unreadCountsProvider =
    StateNotifierProvider<UnreadCountsNotifier, Map<String, int>>((ref) {
  final notifier = UnreadCountsNotifier(ref);

  final selectedTeam = ref.watch(selectedTeamProvider);
  if (selectedTeam != null) {
    Future.microtask(() => notifier.loadForTeam(selectedTeam.slug));
  }

  return notifier;
});

/// Unread count for a specific channel.
final channelUnreadCountProvider = Provider.family<int, String>((ref, channelId) {
  final counts = ref.watch(unreadCountsProvider);
  return counts[channelId] ?? 0;
});

/// Total unread for the current team (for team rail badge).
final totalUnreadProvider = Provider<int>((ref) {
  final counts = ref.watch(unreadCountsProvider);
  return counts.values.fold(0, (a, b) => a + b);
});

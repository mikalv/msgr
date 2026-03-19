import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client_provider.dart';
import 'mock_api_data.dart';
import 'models.dart';
import 'team_list_provider.dart';

// ---------------------------------------------------------------------------
// ChannelList — channels (+ DMs) for the currently selected team
// ---------------------------------------------------------------------------

class ChannelListState {
  const ChannelListState({
    this.channels = const [],
    this.isLoading = false,
    this.error,
  });

  final List<SlackChannel> channels;
  final bool isLoading;
  final Object? error;

  /// Only regular channels (not DMs).
  List<SlackChannel> get publicChannels =>
      channels.where((c) => c.kind == ChannelKind.channel).toList();

  /// Only DM channels.
  List<SlackChannel> get dmChannels =>
      channels.where((c) => c.kind == ChannelKind.dm || c.kind == ChannelKind.groupDm).toList();

  ChannelListState copyWith({
    List<SlackChannel>? channels,
    bool? isLoading,
    Object? error,
  }) {
    return ChannelListState(
      channels: channels ?? this.channels,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ChannelListNotifier extends StateNotifier<ChannelListState> {
  ChannelListNotifier(this._ref) : super(const ChannelListState());

  final Ref _ref;

  /// Fetch channels for a given team slug.
  Future<void> loadForTeam(String teamSlug) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // TODO: GET /api/teams/:slug/channels
      // final client = _ref.read(apiClientProvider);
      // final response = await client.get('/api/teams/$teamSlug/channels');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final channels = mockSlackChannels[teamSlug] ?? [];
      state = state.copyWith(channels: channels, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> createChannel({
    required String teamSlug,
    required String name,
    String? icon,
  }) async {
    try {
      // TODO: POST /api/teams/:slug/channels
      final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
      final channel = SlackChannel(
        id: 'ch-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        slug: slug,
        icon: icon,
        teamSlug: teamSlug,
      );
      state = state.copyWith(channels: [...state.channels, channel]);
    } catch (e) {
      state = state.copyWith(error: e);
    }
  }

  void clear() => state = const ChannelListState();
}

final channelListProvider =
    StateNotifierProvider<ChannelListNotifier, ChannelListState>((ref) {
  final notifier = ChannelListNotifier(ref);

  // Auto-reload when the selected team changes.
  final selectedTeam = ref.watch(selectedTeamProvider);
  if (selectedTeam != null) {
    // Use a post-frame callback to avoid modifying state during build.
    Future.microtask(() => notifier.loadForTeam(selectedTeam.slug));
  }

  return notifier;
});

/// Just the public channels for the current team.
final publicChannelsProvider = Provider<List<SlackChannel>>((ref) {
  return ref.watch(channelListProvider).publicChannels;
});

/// Just the DM channels for the current team.
final dmChannelsProvider = Provider<List<SlackChannel>>((ref) {
  return ref.watch(channelListProvider).dmChannels;
});

// ---------------------------------------------------------------------------
// SelectedChannel — the channel currently being viewed
// ---------------------------------------------------------------------------

class SelectedChannelNotifier extends StateNotifier<SlackChannel?> {
  SelectedChannelNotifier() : super(null);

  void select(SlackChannel channel) => state = channel;
  void clear() => state = null;
}

final selectedChannelProvider =
    StateNotifierProvider<SelectedChannelNotifier, SlackChannel?>((ref) {
  return SelectedChannelNotifier();
});

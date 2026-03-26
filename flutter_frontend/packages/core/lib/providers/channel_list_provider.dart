import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_state_provider.dart';
import 'models.dart';
import 'msgr_client_provider.dart';
import 'team_list_provider.dart';

// ---------------------------------------------------------------------------
// ChannelList -- channels (+ DMs) for the currently selected team
// ---------------------------------------------------------------------------

class ChannelListState {
  const ChannelListState({
    this.channels = const [],
    this.isLoading = false,
    this.error,
  });

  final List<MsgrChannel> channels;
  final bool isLoading;
  final Object? error;

  /// Only regular channels (not DMs).
  List<MsgrChannel> get publicChannels =>
      channels.where((c) => c.kind == ChannelKind.channel).toList();

  /// Only DM channels.
  List<MsgrChannel> get dmChannels =>
      channels
          .where(
              (c) => c.kind == ChannelKind.dm || c.kind == ChannelKind.groupDm)
          .toList();

  ChannelListState copyWith({
    List<MsgrChannel>? channels,
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

ChannelKind _parseChannelKind(String? kind) {
  switch (kind) {
    case 'dm':
      return ChannelKind.dm;
    case 'group_dm':
      return ChannelKind.groupDm;
    default:
      return ChannelKind.channel;
  }
}

class ChannelListNotifier extends StateNotifier<ChannelListState> {
  ChannelListNotifier(this._ref) : super(const ChannelListState());

  final Ref _ref;

  /// Fetch channels for a given team slug.
  Future<void> loadForTeam(String teamSlug) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = _ref.read(msgrApiProvider);
      final data = await client.getChannels(teamSlug);
      final channels = data.map((c) {
        // Parse DM member names if present
        Map<String, String>? memberNames;
        final rawMembers = c['members'];
        if (rawMembers is List) {
          memberNames = {};
          for (final m in rawMembers) {
            if (m is Map) {
              final pid = m['profile_id']?.toString() ?? '';
              final name = m['display_name']?.toString() ?? '';
              if (pid.isNotEmpty && name.isNotEmpty) memberNames[pid] = name;
            }
          }
        }

        return MsgrChannel(
          id: c['id']?.toString() ?? '',
          name: c['name']?.toString() ?? '',
          slug: c['slug']?.toString() ?? c['name']?.toString() ?? '',
          icon: c['icon'] as String?,
          kind: _parseChannelKind(c['kind'] as String?),
          visibility: c['visibility'] == 'private'
              ? ChannelVisibility.private
              : ChannelVisibility.public,
          teamSlug: teamSlug,
          topic: c['topic'] as String?,
          memberNames: memberNames,
        );
      }).toList();
      state = state.copyWith(channels: channels, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  /// Reload channels for the current team.
  Future<void> refresh() async {
    final selectedTeam = _ref.read(selectedTeamProvider);
    if (selectedTeam != null) {
      await loadForTeam(selectedTeam.slug);
    }
  }

  Future<void> createChannel({
    required String teamSlug,
    required String name,
    String? icon,
    String visibility = 'public',
    List<String>? memberIds,
  }) async {
    try {
      final client = _ref.read(msgrApiProvider);
      final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
      final raw = await client.createChannel(teamSlug, name: name, slug: slug, icon: icon, visibility: visibility, memberIds: memberIds);
      // Handle both {data: {...}} and flat response
      final data = raw.containsKey('data') && raw['data'] is Map
          ? raw['data'] as Map<String, dynamic>
          : raw;
      final responseSlug = data['slug']?.toString() ?? slug;
      final channel = MsgrChannel(
        id: data['id']?.toString() ??
            'ch-${DateTime.now().millisecondsSinceEpoch}',
        name: data['name']?.toString() ?? name,
        slug: responseSlug,
        icon: icon,
        kind: _parseChannelKind(data['kind'] as String?),
        teamSlug: teamSlug,
        topic: data['topic'] as String?,
      );
      state = state.copyWith(channels: [...state.channels, channel]);
    } catch (e) {
      state = state.copyWith(error: e);
    }
  }

  /// Leave a channel (remove self as member) and remove from local state.
  Future<void> leaveChannel(String channelId) async {
    try {
      final team = _ref.read(selectedTeamProvider);
      if (team == null) return;

      final client = _ref.read(msgrApiProvider);
      // Get our team profile ID from profiles endpoint
      final profiles = await client.getProfiles(team.slug);
      final accountId = _ref.read(simpleAuthProvider).accountId;
      String? myProfileId;
      for (final p in profiles) {
        if (p['account_id']?.toString() == accountId) {
          myProfileId = p['id']?.toString();
          break;
        }
      }
      if (myProfileId == null) return;

      await client.removeChannelMember(team.slug, channelId, myProfileId);

      // Remove from local state
      state = state.copyWith(
        channels: state.channels.where((c) => c.id != channelId).toList(),
      );
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
final publicChannelsProvider = Provider<List<MsgrChannel>>((ref) {
  return ref.watch(channelListProvider).publicChannels;
});

/// Just the DM channels for the current team.
final dmChannelsProvider = Provider<List<MsgrChannel>>((ref) {
  return ref.watch(channelListProvider).dmChannels;
});

// ---------------------------------------------------------------------------
// SelectedChannel -- the channel currently being viewed
// ---------------------------------------------------------------------------

class SelectedChannelNotifier extends StateNotifier<MsgrChannel?> {
  SelectedChannelNotifier() : super(null);

  void select(MsgrChannel channel) {
    state = channel;
    // Persist last selected channel
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('last_channel_id', channel.id);
    });
  }

  void clear() => state = null;
}

final selectedChannelProvider =
    StateNotifierProvider<SelectedChannelNotifier, MsgrChannel?>((ref) {
  final notifier = SelectedChannelNotifier();

  // Auto-select saved channel when channel list loads
  final channelState = ref.watch(channelListProvider);
  if (channelState.channels.isNotEmpty && !channelState.isLoading) {
    Future.microtask(() async {
      final prefs = await SharedPreferences.getInstance();
      final lastId = prefs.getString('last_channel_id');
      if (lastId != null) {
        final saved = channelState.channels
            .where((c) => c.id == lastId)
            .firstOrNull;
        if (saved != null) {
          notifier.select(saved);
          return;
        }
      }
      // Fall back to first channel
      notifier.select(channelState.channels.first);
    });
  }

  return notifier;
});

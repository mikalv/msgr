import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'mock_api_data.dart';
import 'models.dart';
import 'team_list_provider.dart';

// ---------------------------------------------------------------------------
// TeamPresence — online presence for the currently selected team
// ---------------------------------------------------------------------------

class TeamPresenceNotifier extends StateNotifier<Map<String, PresenceInfo>> {
  TeamPresenceNotifier(this._ref) : super({});

  final Ref _ref;

  /// Connect to presence channel for a team.
  Future<void> connectForTeam(String teamSlug) async {
    // TODO: Connect to presence:{team_slug} Phoenix channel and listen for
    //       presence_state / presence_diff events.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    state = mockPresenceData[teamSlug] ?? {};
  }

  /// Handle a presence diff from Phoenix Presence.
  void applyDiff({
    List<PresenceInfo> joins = const [],
    List<PresenceInfo> leaves = const [],
  }) {
    final updated = Map<String, PresenceInfo>.from(state);
    for (final info in joins) {
      updated[info.profileId] = info;
    }
    for (final info in leaves) {
      updated[info.profileId] = PresenceInfo(
        profileId: info.profileId,
        status: PresenceStatus.offline,
        lastSeenAt: DateTime.now(),
      );
    }
    state = updated;
  }

  /// Check if a specific profile is online.
  bool isOnline(String profileId) {
    return state[profileId]?.status == PresenceStatus.online;
  }

  void clear() => state = {};
}

final teamPresenceProvider =
    StateNotifierProvider<TeamPresenceNotifier, Map<String, PresenceInfo>>((ref) {
  final notifier = TeamPresenceNotifier(ref);

  // Auto-connect when selected team changes.
  final selectedTeam = ref.watch(selectedTeamProvider);
  if (selectedTeam != null) {
    Future.microtask(() => notifier.connectForTeam(selectedTeam.slug));
  }

  return notifier;
});

/// Helper: is a profile online in the current team?
final isProfileOnlineProvider = Provider.family<bool, String>((ref, profileId) {
  final presence = ref.watch(teamPresenceProvider);
  return presence[profileId]?.status == PresenceStatus.online;
});

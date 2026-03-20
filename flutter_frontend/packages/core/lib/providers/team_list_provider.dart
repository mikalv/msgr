import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client_provider.dart';
import 'auth_state_provider.dart';
import 'models.dart';

// ---------------------------------------------------------------------------
// TeamList -- all teams the current user belongs to
// ---------------------------------------------------------------------------

class TeamListState {
  const TeamListState({
    this.teams = const [],
    this.isLoading = false,
    this.error,
  });

  final List<SlackTeam> teams;
  final bool isLoading;
  final Object? error;

  TeamListState copyWith({
    List<SlackTeam>? teams,
    bool? isLoading,
    Object? error,
  }) {
    return TeamListState(
      teams: teams ?? this.teams,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class TeamListNotifier extends StateNotifier<TeamListState> {
  TeamListNotifier(this._ref) : super(const TeamListState()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final auth = _ref.read(simpleAuthProvider);
    if (!auth.isLoggedIn) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = _ref.read(apiClientProvider);
      final data = await client.getTeams();
      final teams = data.map((t) {
        return SlackTeam(
          id: t['id']?.toString() ?? '',
          name: t['name']?.toString() ?? '',
          slug: t['slug']?.toString() ?? '',
          iconEmoji: t['icon_emoji'] as String?,
          domain: t['domain'] as String?,
        );
      }).toList();
      state = state.copyWith(teams: teams, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> refresh() => _load();

  Future<void> createTeam(String name, String slug) async {
    try {
      final client = _ref.read(apiClientProvider);
      final raw = await client.createTeam(name: name, slug: slug);
      // Handle both {data: {...}} and flat response
      final data = raw.containsKey('data') && raw['data'] is Map
          ? raw['data'] as Map<String, dynamic>
          : raw;
      final team = SlackTeam(
        id: data['id']?.toString() ?? 'team-${DateTime.now().millisecondsSinceEpoch}',
        name: data['name']?.toString() ?? name,
        slug: data['slug']?.toString() ?? slug,
        iconEmoji: data['icon_emoji'] as String?,
      );
      state = state.copyWith(teams: [...state.teams, team]);
    } catch (e) {
      state = state.copyWith(error: e);
    }
  }

  Future<void> joinTeam(String slug) async {
    try {
      final client = _ref.read(apiClientProvider);
      final raw = await client.joinTeam(slug);
      final data = raw.containsKey('data') && raw['data'] is Map
          ? raw['data'] as Map<String, dynamic>
          : raw;
      final team = SlackTeam(
        id: data['id']?.toString() ?? 'team-${DateTime.now().millisecondsSinceEpoch}',
        name: data['name']?.toString() ?? slug,
        slug: data['slug']?.toString() ?? slug,
        iconEmoji: data['icon_emoji'] as String?,
      );
      state = state.copyWith(teams: [...state.teams, team]);
    } catch (e) {
      state = state.copyWith(error: e);
    }
  }
}

final teamListProvider =
    StateNotifierProvider<TeamListNotifier, TeamListState>((ref) {
  // Re-create when auth state changes
  ref.watch(simpleAuthProvider);
  return TeamListNotifier(ref);
});

/// Convenience provider for just the list of teams.
final teamsProvider = Provider<List<SlackTeam>>((ref) {
  return ref.watch(teamListProvider).teams;
});

// ---------------------------------------------------------------------------
// SelectedTeam -- the team currently being viewed
// ---------------------------------------------------------------------------

class SelectedTeamNotifier extends StateNotifier<SlackTeam?> {
  SelectedTeamNotifier() : super(null);

  void select(SlackTeam team) {
    state = team;
    // Persist last selected team
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('last_team_slug', team.slug);
    });
  }

  void clear() => state = null;
}

final selectedTeamProvider =
    StateNotifierProvider<SelectedTeamNotifier, SlackTeam?>((ref) {
  final teams = ref.watch(teamListProvider).teams;
  final notifier = SelectedTeamNotifier();
  if (teams.isNotEmpty) {
    // Try to restore last selected team from prefs
    Future.microtask(() async {
      final prefs = await SharedPreferences.getInstance();
      final lastSlug = prefs.getString('last_team_slug');
      if (lastSlug != null) {
        final savedTeam = teams.where((t) => t.slug == lastSlug).firstOrNull;
        if (savedTeam != null) {
          notifier.select(savedTeam);
          return;
        }
      }
      // Fall back to first team
      notifier.select(teams.first);
    });
  }
  return notifier;
});

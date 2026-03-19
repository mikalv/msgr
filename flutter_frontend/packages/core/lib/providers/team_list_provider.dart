import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client_provider.dart';
import 'mock_api_data.dart';
import 'models.dart';

// ---------------------------------------------------------------------------
// TeamList — all teams the current user belongs to
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
    state = state.copyWith(isLoading: true, error: null);
    try {
      // TODO: Replace with real API call: GET /api/teams
      // final client = _ref.read(apiClientProvider);
      // final response = await client.get('/api/teams');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      state = state.copyWith(
        teams: mockSlackTeams,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> refresh() => _load();

  Future<void> createTeam(String name, String slug) async {
    try {
      // TODO: POST /api/teams
      final team = SlackTeam(
        id: 'team-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        slug: slug,
      );
      state = state.copyWith(teams: [...state.teams, team]);
    } catch (e) {
      state = state.copyWith(error: e);
    }
  }

  Future<void> joinTeam(String slug) async {
    try {
      // TODO: POST /api/teams/:slug/join
      final team = SlackTeam(
        id: 'team-${DateTime.now().millisecondsSinceEpoch}',
        name: slug,
        slug: slug,
      );
      state = state.copyWith(teams: [...state.teams, team]);
    } catch (e) {
      state = state.copyWith(error: e);
    }
  }
}

final teamListProvider =
    StateNotifierProvider<TeamListNotifier, TeamListState>((ref) {
  return TeamListNotifier(ref);
});

/// Convenience provider for just the list of teams.
final teamsProvider = Provider<List<SlackTeam>>((ref) {
  return ref.watch(teamListProvider).teams;
});

// ---------------------------------------------------------------------------
// SelectedTeam — the team currently being viewed
// ---------------------------------------------------------------------------

class SelectedTeamNotifier extends StateNotifier<SlackTeam?> {
  SelectedTeamNotifier() : super(null);

  void select(SlackTeam team) => state = team;

  void clear() => state = null;
}

final selectedTeamProvider =
    StateNotifierProvider<SelectedTeamNotifier, SlackTeam?>((ref) {
  // Auto-select first team when team list loads, if nothing is selected yet.
  final teams = ref.watch(teamListProvider).teams;
  final notifier = SelectedTeamNotifier();
  if (teams.isNotEmpty) {
    notifier.select(teams.first);
  }
  return notifier;
});

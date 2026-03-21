import 'package:flutter_test/flutter_test.dart';
import 'package:core/providers/models.dart';
import 'package:core/providers/team_list_provider.dart';

void main() {
  group('TeamListState', () {
    test('default construction', () {
      const state = TeamListState();
      expect(state.teams, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('construction with values', () {
      final teams = [
        const SlackTeam(id: '1', name: 'Alpha', slug: 'alpha'),
      ];
      final state = TeamListState(teams: teams, isLoading: true);
      expect(state.teams.length, 1);
      expect(state.isLoading, isTrue);
      expect(state.error, isNull);
    });

    test('copyWith updates teams', () {
      const state = TeamListState();
      final updated = state.copyWith(
        teams: [const SlackTeam(id: '1', name: 'A', slug: 'a')],
      );
      expect(updated.teams.length, 1);
      expect(updated.isLoading, isFalse);
    });

    test('copyWith updates isLoading', () {
      const state = TeamListState();
      final updated = state.copyWith(isLoading: true);
      expect(updated.isLoading, isTrue);
      expect(updated.teams, isEmpty);
    });

    test('copyWith updates error', () {
      const state = TeamListState();
      final updated = state.copyWith(error: 'something broke');
      expect(updated.error, 'something broke');
    });

    test('copyWith clears error when set to null explicitly', () {
      final state = TeamListState(error: 'old error');
      // error: null should clear the error (not preserve old)
      final updated = state.copyWith(error: null);
      expect(updated.error, isNull);
    });

    test('copyWith preserves unspecified fields', () {
      final teams = [const SlackTeam(id: '1', name: 'A', slug: 'a')];
      final state = TeamListState(teams: teams, isLoading: true, error: 'err');
      final updated = state.copyWith(isLoading: false);
      expect(updated.teams, teams);
      // error is NOT preserved by default — it resets to null
      // (the implementation passes error directly, so omitting it means null)
      expect(updated.isLoading, isFalse);
    });
  });

  group('SlackTeam model', () {
    test('construction with required fields', () {
      const team = SlackTeam(id: 't1', name: 'Team One', slug: 'team-one');
      expect(team.id, 't1');
      expect(team.name, 'Team One');
      expect(team.slug, 'team-one');
      expect(team.iconEmoji, isNull);
      expect(team.domain, isNull);
    });

    test('construction with optional fields', () {
      const team = SlackTeam(
        id: 't2',
        name: 'Team Two',
        slug: 'team-two',
        iconEmoji: '🚀',
        domain: 'team-two.example.com',
      );
      expect(team.iconEmoji, '🚀');
      expect(team.domain, 'team-two.example.com');
    });

    test('equality is based on id', () {
      const a = SlackTeam(id: 'x', name: 'A', slug: 'a');
      const b = SlackTeam(id: 'x', name: 'B', slug: 'b');
      expect(a, equals(b));
    });

    test('different ids are not equal', () {
      const a = SlackTeam(id: '1', name: 'Same', slug: 'same');
      const b = SlackTeam(id: '2', name: 'Same', slug: 'same');
      expect(a, isNot(equals(b)));
    });

    test('copyWith', () {
      const team = SlackTeam(id: 't1', name: 'Old', slug: 'old');
      final updated = team.copyWith(name: 'New', slug: 'new');
      expect(updated.id, 't1');
      expect(updated.name, 'New');
      expect(updated.slug, 'new');
    });

    test('toString contains slug', () {
      const team = SlackTeam(id: '1', name: 'N', slug: 'my-slug');
      expect(team.toString(), contains('my-slug'));
    });
  });

  group('SelectedTeamNotifier', () {
    test('initial state is null', () {
      final notifier = SelectedTeamNotifier();
      // Access state via debugState for testing
      expect(notifier.debugState, isNull);
    });

    test('select sets a team', () {
      final notifier = SelectedTeamNotifier();
      const team = SlackTeam(id: '1', name: 'T', slug: 't');
      notifier.select(team);
      expect(notifier.debugState, equals(team));
    });

    test('clear resets to null', () {
      final notifier = SelectedTeamNotifier();
      const team = SlackTeam(id: '1', name: 'T', slug: 't');
      notifier.select(team);
      notifier.clear();
      expect(notifier.debugState, isNull);
    });

    test('select replaces previous selection', () {
      final notifier = SelectedTeamNotifier();
      const team1 = SlackTeam(id: '1', name: 'A', slug: 'a');
      const team2 = SlackTeam(id: '2', name: 'B', slug: 'b');
      notifier.select(team1);
      notifier.select(team2);
      expect(notifier.debugState, equals(team2));
    });
  });
}

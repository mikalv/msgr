import 'package:flutter_test/flutter_test.dart';
import 'package:core/providers/mention_provider.dart';

/// Fake API that returns canned profile data.
class _FakeApi {
  final List<Map<String, dynamic>> profiles;
  _FakeApi(this.profiles);

  Future<List<Map<String, dynamic>>> getProfiles(String teamSlug) async {
    return profiles;
  }
}

/// Fake API that throws on getProfiles.
class _FailingApi {
  Future<List<Map<String, dynamic>>> getProfiles(String teamSlug) async {
    throw Exception('network error');
  }
}

void main() {
  group('MentionState', () {
    test('default construction', () {
      const state = MentionState();
      expect(state.mentions, isEmpty);
      expect(state.loaded, isFalse);
    });

    test('construction with values', () {
      const state = MentionState(mentions: [], loaded: true);
      expect(state.loaded, isTrue);
    });
  });

  group('MentionNotifier', () {
    test('initial state is not loaded', () {
      final notifier = MentionNotifier();
      expect(notifier.debugState.loaded, isFalse);
      expect(notifier.debugState.mentions, isEmpty);
    });

    test('load populates state with special mentions and profiles', () async {
      final api = _FakeApi([
        {'id': 'p1', 'display_name': 'Alice', 'account_id': 'acc-other'},
        {'id': 'p2', 'display_name': 'Bob', 'account_id': 'acc-bob'},
      ]);

      final notifier = MentionNotifier();
      await notifier.load('team-slug', api, myAccountId: 'acc-me');

      final state = notifier.debugState;
      expect(state.loaded, isTrue);
      // Should have @channel, @here, Alice, Bob
      expect(state.mentions.length, 4);
      expect(state.mentions[0].handle, 'channel');
      expect(state.mentions[1].handle, 'here');
      expect(state.mentions.any((m) => m.displayName == 'Alice'), isTrue);
      expect(state.mentions.any((m) => m.displayName == 'Bob'), isTrue);
    });

    test('load filters out own profile', () async {
      final api = _FakeApi([
        {'id': 'p1', 'display_name': 'Me', 'account_id': 'acc-me'},
        {'id': 'p2', 'display_name': 'Other', 'account_id': 'acc-other'},
      ]);

      final notifier = MentionNotifier();
      await notifier.load('team-slug', api, myAccountId: 'acc-me');

      final names = notifier.debugState.mentions.map((m) => m.displayName).toList();
      expect(names, isNot(contains('Me')));
      expect(names, contains('Other'));
    });

    test('special mentions always present (@channel, @here)', () async {
      final api = _FakeApi([]);
      final notifier = MentionNotifier();
      await notifier.load('team-slug', api);

      final handles = notifier.debugState.mentions.map((m) => m.handle).toList();
      expect(handles, contains('channel'));
      expect(handles, contains('here'));
    });

    test('load is idempotent (skips if already loaded)', () async {
      final api = _FakeApi([
        {'id': 'p1', 'display_name': 'Alice', 'account_id': 'acc-1'},
      ]);

      final notifier = MentionNotifier();
      await notifier.load('team-slug', api);
      final firstCount = notifier.debugState.mentions.length;

      // Second load should be a no-op
      final api2 = _FakeApi([
        {'id': 'p1', 'display_name': 'Alice', 'account_id': 'acc-1'},
        {'id': 'p2', 'display_name': 'Bob', 'account_id': 'acc-2'},
      ]);
      await notifier.load('team-slug', api2);
      expect(notifier.debugState.mentions.length, firstCount);
    });

    test('reset clears state', () async {
      final api = _FakeApi([
        {'id': 'p1', 'display_name': 'Alice', 'account_id': 'acc-1'},
      ]);

      final notifier = MentionNotifier();
      await notifier.load('team-slug', api);
      expect(notifier.debugState.loaded, isTrue);

      notifier.reset();
      expect(notifier.debugState.loaded, isFalse);
      expect(notifier.debugState.mentions, isEmpty);
    });

    test('load after reset re-fetches', () async {
      final api = _FakeApi([
        {'id': 'p1', 'display_name': 'Alice', 'account_id': 'acc-1'},
      ]);

      final notifier = MentionNotifier();
      await notifier.load('team-slug', api);
      notifier.reset();
      await notifier.load('team-slug', api);
      expect(notifier.debugState.loaded, isTrue);
      // @channel, @here, Alice
      expect(notifier.debugState.mentions.length, 3);
    });

    test('load handles API failure gracefully', () async {
      final api = _FailingApi();
      final notifier = MentionNotifier();
      await notifier.load('team-slug', api);

      // Should still be loaded (with just special mentions as fallback)
      expect(notifier.debugState.loaded, isTrue);
      expect(notifier.debugState.mentions.length, 2); // @channel, @here
    });

    test('profiles with empty id are filtered out', () async {
      final api = _FakeApi([
        {'id': '', 'display_name': 'Ghost', 'account_id': 'acc-ghost'},
        {'id': 'p2', 'display_name': 'Valid', 'account_id': 'acc-valid'},
      ]);

      final notifier = MentionNotifier();
      await notifier.load('team-slug', api);

      final names = notifier.debugState.mentions.map((m) => m.displayName).toList();
      expect(names, isNot(contains('Ghost')));
      expect(names, contains('Valid'));
    });
  });
}

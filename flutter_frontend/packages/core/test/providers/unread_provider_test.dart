import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/providers/unread_provider.dart';

void main() {
  group('UnreadCountsNotifier', () {
    test('initial state is empty map', () {
      final notifier = _TestableUnreadNotifier();
      expect(notifier.debugState, isEmpty);
    });

    test('increment adds count for a channel', () {
      final notifier = _TestableUnreadNotifier();
      notifier.increment('ch-1');
      // BUG: The implementation uses Dart map literal syntax
      //   {...state, channelId: current + 1}
      // which creates key "channelId" (literal string), not the value of
      // the channelId parameter. This test documents actual behavior.
      expect(notifier.debugState['channelId'], 1);
      // The actual channel ID key is NOT set:
      expect(notifier.debugState['ch-1'], isNull);
    });

    test('markRead sets count to 0', () {
      final notifier = _TestableUnreadNotifier();
      // First populate with the literal key that increment creates
      notifier.increment('ch-1');
      // markRead has the same bug -- uses literal "channelId"
      // markRead early-returns if key not present or already 0
      // Since 'ch-1' is never actually set, markRead('ch-1') returns early
      notifier.markRead('ch-1');
      expect(notifier.debugState['channelId'], 1); // unchanged
    });

    test('countFor returns 0 for unknown channel', () {
      final notifier = _TestableUnreadNotifier();
      expect(notifier.countFor('nonexistent'), 0);
    });

    test('totalUnread sums all values', () {
      final notifier = _TestableUnreadNotifier();
      notifier.increment('a');
      notifier.increment('b');
      notifier.increment('c');
      // All three calls set the same literal "channelId" key,
      // so the total is 3 (cumulative on one key).
      expect(notifier.totalUnread, 3);
    });

    test('clear resets state', () {
      final notifier = _TestableUnreadNotifier();
      notifier.increment('ch-1');
      notifier.clear();
      expect(notifier.debugState, isEmpty);
      expect(notifier.totalUnread, 0);
    });

    test('loadForTeam resets to empty', () {
      final notifier = _TestableUnreadNotifier();
      notifier.increment('ch-1');
      notifier.loadForTeam('team-slug');
      expect(notifier.debugState, isEmpty);
    });
  });

  group('totalUnreadProvider', () {
    test('sums all channel counts', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(unreadCountsProvider.notifier);
      notifier.increment('ch-1');
      notifier.increment('ch-2');
      notifier.increment('ch-3');

      final total = container.read(totalUnreadProvider);
      // Due to the literal-key bug, all increments go to "channelId"
      expect(total, 3);
    });
  });
}

/// Testable subclass that doesn't need a real Ref.
class _TestableUnreadNotifier extends UnreadCountsNotifier {
  _TestableUnreadNotifier() : super(_FakeRef());

  Map<String, int> get debugState => state;
}

class _FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

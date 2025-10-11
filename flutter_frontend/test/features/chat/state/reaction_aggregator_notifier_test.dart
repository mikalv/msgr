import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/features/chat/models/reaction_aggregate.dart';
import 'package:messngr/features/chat/state/reaction_aggregator_notifier.dart';

void main() {
  test('apply replaces aggregates for message', () {
    final notifier = ReactionAggregatorNotifier();
    notifier.apply('msg-1', const [ReactionAggregate(emoji: '👍', count: 1, profileIds: ['a'])]);

    final aggregates = notifier.aggregatesFor('msg-1');
    expect(aggregates.length, 1);
    expect(aggregates.first.count, 1);

    notifier.apply('msg-1', const [ReactionAggregate(emoji: '👍', count: 3, profileIds: ['a', 'b'])]);

    final updated = notifier.aggregatesFor('msg-1');
    expect(updated.first.count, 3);
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:core/providers/models.dart';
import 'package:core/providers/messages_provider.dart';

void main() {
  group('ChannelMessagesState', () {
    test('default construction', () {
      const state = ChannelMessagesState();
      expect(state.messages, isEmpty);
      expect(state.isLoading, false);
      expect(state.isLoadingMore, false);
      expect(state.hasMore, true);
      expect(state.error, isNull);
      expect(state.cursor, isNull);
    });

    test('copyWith preserves values when no args given', () {
      final state = ChannelMessagesState(
        messages: [_msg('1')],
        isLoading: true,
        hasMore: false,
        cursor: 'c-1',
      );
      final copy = state.copyWith();
      expect(copy.messages.length, 1);
      expect(copy.isLoading, true);
      expect(copy.hasMore, false);
      expect(copy.cursor, 'c-1');
      // error is explicitly set to null in copyWith (not preserved)
      expect(copy.error, isNull);
    });

    test('copyWith overrides specified fields', () {
      const state = ChannelMessagesState(isLoading: true);
      final updated = state.copyWith(isLoading: false, cursor: 'abc');
      expect(updated.isLoading, false);
      expect(updated.cursor, 'abc');
    });

    test('copyWith clears error when not passed', () {
      final state = ChannelMessagesState(error: 'some error');
      final cleared = state.copyWith();
      // The copyWith uses `error: error` (positional), so it's null by default
      expect(cleared.error, isNull);
    });
  });

  group('_extractContent (via parseMessageJson)', () {
    test('handles String content', () {
      final msg = parseMessageJson({
        'id': '1',
        'content': 'Hello world',
        'inserted_at': '2024-01-01T00:00:00Z',
        'sender_profile': {'id': 'p1', 'display_name': 'User'},
        'profile_id': 'p1',
      }, 'ch-1');
      expect(msg.content, 'Hello world');
    });

    test('handles Map content with text key', () {
      final msg = parseMessageJson({
        'id': '2',
        'content': {'text': 'Rich message', 'mentions': []},
        'inserted_at': '2024-01-01T00:00:00Z',
        'sender_profile': {'id': 'p1', 'display_name': 'User'},
        'profile_id': 'p1',
      }, 'ch-1');
      expect(msg.content, 'Rich message');
    });

    test('handles null content', () {
      final msg = parseMessageJson({
        'id': '3',
        'content': null,
        'inserted_at': '2024-01-01T00:00:00Z',
        'sender_profile': {'id': 'p1', 'display_name': 'User'},
        'profile_id': 'p1',
      }, 'ch-1');
      expect(msg.content, '');
    });

    test('handles Map content without text key', () {
      final msg = parseMessageJson({
        'id': '4',
        'content': {'type': 'system', 'action': 'join'},
        'inserted_at': '2024-01-01T00:00:00Z',
        'sender_profile': {'id': 'p1', 'display_name': 'User'},
        'profile_id': 'p1',
      }, 'ch-1');
      // Falls back to content.toString() since no 'text' key
      expect(msg.content, isNotEmpty);
    });
  });

  group('parseMessageJson', () {
    test('parses reactions', () {
      final msg = parseMessageJson({
        'id': 'r1',
        'content': 'Hi',
        'inserted_at': '2024-06-01T12:00:00Z',
        'sender_profile': {'id': 'p1', 'display_name': 'User'},
        'profile_id': 'p1',
        'reactions': [
          {
            'emoji': 'thumbsup',
            'count': 2,
            'profile_ids': ['p1', 'p2'],
          }
        ],
      }, 'ch-1', currentProfileId: 'p1');

      expect(msg.reactions.length, 1);
      expect(msg.reactions.first.emoji, 'thumbsup');
      expect(msg.reactions.first.count, 2);
      expect(msg.reactions.first.includesMe, true);
    });

    test('extracts mentions from Map content', () {
      final msg = parseMessageJson({
        'id': 'm1',
        'content': {
          'text': 'Hey @Alice',
          'mentions': [
            {
              'profile_id': 'alice-1',
              'display_name': 'Alice',
              'offset': 4,
              'length': 6,
            }
          ],
        },
        'inserted_at': '2024-06-01T12:00:00Z',
        'sender_profile': {'id': 'p1', 'display_name': 'User'},
        'profile_id': 'p1',
      }, 'ch-1');

      expect(msg.mentions.length, 1);
      expect(msg.mentions.first.profileId, 'alice-1');
      expect(msg.mentions.first.displayName, 'Alice');
    });

    test('detects system message when sender is empty', () {
      final msg = parseMessageJson({
        'id': 's1',
        'content': 'Channel created',
        'inserted_at': '2024-06-01T12:00:00Z',
        // No sender_profile
      }, 'ch-1');

      expect(msg.isSystem, true);
      expect(msg.senderName, 'System');
    });
  });

  group('ChannelMessagesNotifier.mergeIncoming', () {
    test('replaces existing message by ID', () {
      final notifier = _TestableMessagesNotifier();
      notifier.setState(ChannelMessagesState(messages: [
        _msg('1', content: 'Old'),
        _msg('2'),
      ]));

      notifier.mergeIncoming(_msg('1', content: 'Updated'));

      expect(notifier.state.messages.length, 2);
      expect(notifier.state.messages.first.content, 'Updated');
    });

    test('replaces optimistic local-* message by content match', () {
      final notifier = _TestableMessagesNotifier();
      notifier.setState(ChannelMessagesState(messages: [
        _msg('local-12345', content: 'Hello', channelId: 'ch-1'),
      ]));

      notifier.mergeIncoming(
        _msg('server-99', content: 'Hello', channelId: 'ch-1'),
      );

      expect(notifier.state.messages.length, 1);
      expect(notifier.state.messages.first.id, 'server-99');
    });

    test('appends new message when no match found', () {
      final notifier = _TestableMessagesNotifier();
      notifier.setState(ChannelMessagesState(messages: [_msg('1')]));

      notifier.mergeIncoming(_msg('2'));

      expect(notifier.state.messages.length, 2);
    });

    test('does not duplicate when ID already exists', () {
      final notifier = _TestableMessagesNotifier();
      notifier.setState(ChannelMessagesState(messages: [
        _msg('1'),
        _msg('2'),
      ]));

      notifier.mergeIncoming(_msg('1'));

      expect(notifier.state.messages.length, 2);
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

SlackMessage _msg(
  String id, {
  String content = 'test',
  String channelId = 'ch-1',
  MessageStatus status = MessageStatus.sent,
}) {
  return SlackMessage(
    id: id,
    channelId: channelId,
    senderProfileId: 'p1',
    senderName: 'Tester',
    content: content,
    insertedAt: DateTime(2024, 1, 1),
    status: status,
  );
}

/// A testable subclass that exposes setState for direct state manipulation
/// without needing a Ref (which requires wiring up other providers).
class _TestableMessagesNotifier extends ChannelMessagesNotifier {
  _TestableMessagesNotifier() : super(_FakeRef());

  void setState(ChannelMessagesState newState) {
    state = newState;
  }
}

/// Minimal fake Ref -- only used to satisfy the constructor.
/// Methods that actually use _ref are not called in these unit tests.
class _FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

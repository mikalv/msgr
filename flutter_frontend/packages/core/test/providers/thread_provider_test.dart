import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/providers/models.dart';
import 'package:core/providers/thread_provider.dart';

SlackMessage _makeMessage({
  required String id,
  String channelId = 'ch-1',
  String? threadParentId,
}) {
  return SlackMessage(
    id: id,
    channelId: channelId,
    senderProfileId: 'prof-1',
    senderName: 'Alice',
    content: 'Message $id',
    insertedAt: DateTime(2025, 1, 1),
    threadParentId: threadParentId,
  );
}

void main() {
  group('ThreadMessagesState', () {
    test('default construction', () {
      const state = ThreadMessagesState();
      expect(state.parentMessageId, isNull);
      expect(state.parentMessage, isNull);
      expect(state.replies, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.isOpen, isFalse);
    });

    test('isOpen is true when parentMessageId is set', () {
      final state = ThreadMessagesState(parentMessageId: 'msg-1');
      expect(state.isOpen, isTrue);
    });

    test('copyWith updates replies', () {
      const state = ThreadMessagesState();
      final replies = [_makeMessage(id: 'r1', threadParentId: 'p1')];
      final updated = state.copyWith(replies: replies);
      expect(updated.replies.length, 1);
      expect(updated.replies.first.id, 'r1');
    });

    test('copyWith updates isLoading', () {
      const state = ThreadMessagesState();
      final updated = state.copyWith(isLoading: true);
      expect(updated.isLoading, isTrue);
    });

    test('copyWith updates error', () {
      const state = ThreadMessagesState();
      final updated = state.copyWith(error: 'fail');
      expect(updated.error, 'fail');
    });

    test('copyWith preserves existing values when not specified', () {
      final parent = _makeMessage(id: 'p1');
      final state = ThreadMessagesState(
        parentMessageId: 'p1',
        parentMessage: parent,
        replies: [_makeMessage(id: 'r1', threadParentId: 'p1')],
        isLoading: true,
      );
      final updated = state.copyWith(isLoading: false);
      expect(updated.parentMessageId, 'p1');
      expect(updated.parentMessage, parent);
      expect(updated.replies.length, 1);
      expect(updated.isLoading, isFalse);
    });
  });

  group('ThreadMessagesNotifier', () {
    late ProviderContainer container;
    late ThreadMessagesNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(threadMessagesProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is closed', () {
      final state = container.read(threadMessagesProvider);
      expect(state.isOpen, isFalse);
      expect(state.replies, isEmpty);
    });

    test('mergeIncomingReply ignores replies for different parent', () {
      // Open a "thread" by setting state manually via mergeIncoming
      // First set parentMessageId by using copyWith-like behavior
      // Since we can't call openThread without API, test mergeIncomingReply logic
      final reply = _makeMessage(id: 'r1', threadParentId: 'other-parent');
      notifier.mergeIncomingReply(reply);
      final state = container.read(threadMessagesProvider);
      // parentMessageId is null, reply has different parent, so it's ignored
      expect(state.replies, isEmpty);
    });

    test('closeThread resets state', () {
      notifier.closeThread();
      final state = container.read(threadMessagesProvider);
      expect(state.isOpen, isFalse);
      expect(state.parentMessageId, isNull);
      expect(state.replies, isEmpty);
    });
  });
}

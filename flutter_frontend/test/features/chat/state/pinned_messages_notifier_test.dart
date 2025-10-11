import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/features/chat/state/pinned_messages_notifier.dart';

void main() {
  test('pin and unpin messages update list', () {
    final notifier = PinnedMessagesNotifier();
    final info = PinnedMessageInfo(
      messageId: 'msg-1',
      pinnedById: 'a',
      pinnedAt: DateTime.utc(2024, 1, 1, 12, 0),
    );

    notifier.pin(info);
    expect(notifier.pinnedMessages.length, 1);
    expect(notifier.isPinned('msg-1'), isTrue);

    notifier.unpin('msg-1');
    expect(notifier.pinnedMessages, isEmpty);
  });
}

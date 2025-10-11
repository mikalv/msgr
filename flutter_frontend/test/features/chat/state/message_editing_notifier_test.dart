import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/features/chat/state/message_editing_notifier.dart';

void main() {
  test('startEditing and cancelEditing update state', () {
    final notifier = MessageEditingNotifier();
    notifier.startEditing('msg-1', body: 'Hei');

    expect(notifier.editingMessageId, 'msg-1');
    expect(notifier.originalBody, 'Hei');

    notifier.cancelEditing();
    expect(notifier.editingMessageId, isNull);
    expect(notifier.originalBody, isNull);
  });

  test('markDeleted tracks deleted messages', () {
    final notifier = MessageEditingNotifier();
    notifier.markDeleted('msg-1');
    expect(notifier.isDeleted('msg-1'), isTrue);

    notifier.restore('msg-1');
    expect(notifier.isDeleted('msg-1'), isFalse);
  });
}

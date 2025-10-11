import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/features/chat/state/thread_view_notifier.dart';

void main() {
  test('openThread updates state and closeThread resets', () {
    final notifier = ThreadViewNotifier();
    notifier.openThread('thread-1', rootMessageId: 'root');

    expect(notifier.state.threadId, 'thread-1');
    expect(notifier.state.rootMessageId, 'root');

    notifier.closeThread();
    expect(notifier.state.threadId, isNull);
  });

  test('setPinnedView toggles pinned mode', () {
    final notifier = ThreadViewNotifier();
    notifier.setPinnedView(true);
    expect(notifier.state.showPinned, isTrue);

    notifier.setPinnedView(false);
    expect(notifier.state.showPinned, isFalse);
  });
}

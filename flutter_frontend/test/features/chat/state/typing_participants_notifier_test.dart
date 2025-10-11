import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/features/chat/state/typing_participants_notifier.dart';

void main() {
  test('setTyping adds participants and prune removes expired', () {
    final notifier = TypingParticipantsNotifier();
    notifier.setTyping(profileId: 'a', profileName: 'Anna');
    notifier.setTyping(
      profileId: 'b',
      profileName: 'Bjørn',
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
    );

    expect(notifier.activeByThread['root']!.length, 2);

    notifier.pruneExpired(DateTime.now());

    final remaining = notifier.activeByThread['root']!;
    expect(remaining.length, 1);
    expect(remaining.first.profileId, 'a');
  });

  test('stopTyping removes participant from specific thread', () {
    final notifier = TypingParticipantsNotifier();
    notifier.setTyping(profileId: 'a', profileName: 'Anna', threadId: 'thread-1');
    notifier.setTyping(profileId: 'b', profileName: 'Bjørn', threadId: 'thread-1');

    notifier.stopTyping(profileId: 'a', threadId: 'thread-1');

    final participants = notifier.activeByThread['thread-1']!;
    expect(participants.length, 1);
    expect(participants.first.profileId, 'b');
  });
}

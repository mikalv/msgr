import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/providers/typing_provider.dart';

void main() {
  group('TypingIndicatorsNotifier', () {
    late TypingIndicatorsNotifier notifier;

    setUp(() {
      notifier = TypingIndicatorsNotifier();
    });

    tearDown(() {
      notifier.dispose();
    });

    test('initial state is empty', () {
      expect(notifier.debugState, isEmpty);
    });

    test('setTyping adds a user to a channel', () {
      notifier.setTyping('ch-1', 'Alice');
      expect(notifier.debugState['ch-1'], contains('Alice'));
    });

    test('setTyping does not duplicate same user', () {
      notifier.setTyping('ch-1', 'Alice');
      notifier.setTyping('ch-1', 'Alice');
      expect(notifier.debugState['ch-1']!.length, 1);
    });

    test('setTyping tracks multiple users in same channel', () {
      notifier.setTyping('ch-1', 'Alice');
      notifier.setTyping('ch-1', 'Bob');
      expect(notifier.debugState['ch-1'], containsAll(['Alice', 'Bob']));
      expect(notifier.debugState['ch-1']!.length, 2);
    });

    test('setTyping tracks users across different channels', () {
      notifier.setTyping('ch-1', 'Alice');
      notifier.setTyping('ch-2', 'Bob');
      expect(notifier.debugState['ch-1'], ['Alice']);
      expect(notifier.debugState['ch-2'], ['Bob']);
    });

    test('stopTyping removes a user from a channel', () {
      notifier.setTyping('ch-1', 'Alice');
      notifier.setTyping('ch-1', 'Bob');
      notifier.stopTyping('ch-1', 'Alice');
      expect(notifier.debugState['ch-1'], ['Bob']);
    });

    test('stopTyping removes channel entry when last user stops', () {
      notifier.setTyping('ch-1', 'Alice');
      notifier.stopTyping('ch-1', 'Alice');
      expect(notifier.debugState.containsKey('ch-1'), isFalse);
    });

    test('stopTyping is safe for unknown channel', () {
      notifier.stopTyping('nonexistent', 'Nobody');
      expect(notifier.debugState, isEmpty);
    });

    test('clearChannel removes all typing for a channel', () {
      notifier.setTyping('ch-1', 'Alice');
      notifier.setTyping('ch-1', 'Bob');
      notifier.setTyping('ch-2', 'Carol');
      notifier.clearChannel('ch-1');
      expect(notifier.debugState.containsKey('ch-1'), isFalse);
      expect(notifier.debugState['ch-2'], ['Carol']);
    });

    test('clear removes everything', () {
      notifier.setTyping('ch-1', 'Alice');
      notifier.setTyping('ch-2', 'Bob');
      notifier.clear();
      expect(notifier.debugState, isEmpty);
    });

    test('auto-expiry removes typing after duration', () async {
      notifier.setTyping('ch-1', 'Alice',
          duration: const Duration(milliseconds: 100));
      expect(notifier.debugState['ch-1'], ['Alice']);

      // Wait for expiry
      await Future.delayed(const Duration(milliseconds: 200));

      expect(notifier.debugState.containsKey('ch-1'), isFalse);
    });

    test('setTyping resets expiry timer on repeated call', () async {
      notifier.setTyping('ch-1', 'Alice',
          duration: const Duration(milliseconds: 150));

      // Reset timer before first expires
      await Future.delayed(const Duration(milliseconds: 100));
      notifier.setTyping('ch-1', 'Alice',
          duration: const Duration(milliseconds: 150));

      // Original timer would have fired by now
      await Future.delayed(const Duration(milliseconds: 100));
      expect(notifier.debugState['ch-1'], ['Alice']);

      // But the new timer fires
      await Future.delayed(const Duration(milliseconds: 100));
      expect(notifier.debugState.containsKey('ch-1'), isFalse);
    });
  });

  group('channelTypingProvider', () {
    test('returns empty list for unknown channel', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final typing = container.read(channelTypingProvider('ch-unknown'));
      expect(typing, isEmpty);
    });

    test('returns typing users for a channel', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(typingIndicatorsProvider.notifier);
      notifier.setTyping('ch-1', 'Alice');
      notifier.setTyping('ch-1', 'Bob');
      notifier.setTyping('ch-2', 'Carol');

      final ch1Typing = container.read(channelTypingProvider('ch-1'));
      expect(ch1Typing, containsAll(['Alice', 'Bob']));

      final ch2Typing = container.read(channelTypingProvider('ch-2'));
      expect(ch2Typing, ['Carol']);
    });
  });
}

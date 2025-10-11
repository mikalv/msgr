import 'package:msgr_messages/msgr_messages.dart';
import 'package:test/test.dart';

void main() {
  group('MsgrSnackbarMessage', () {
    test('supports value equality', () {
      const messageA = MsgrSnackbarMessage(
        id: 'a',
        title: 'Saved',
        intent: MsgrSnackbarIntent.success,
      );
      const messageB = MsgrSnackbarMessage(
        id: 'a',
        title: 'Saved',
        intent: MsgrSnackbarIntent.success,
      );

      expect(messageA, equals(messageB));
    });

    test('copyWith overrides provided fields', () {
      const base = MsgrSnackbarMessage(
        id: '1',
        title: 'Initial',
        intent: MsgrSnackbarIntent.info,
        body: 'Hello',
        actionLabel: 'Undo',
      );

      final copy = base.copyWith(
        id: '2',
        title: 'Updated',
        intent: MsgrSnackbarIntent.error,
        duration: const Duration(seconds: 10),
        body: 'World',
        actionLabel: 'Retry',
        metadata: const {'traceId': 'abc'},
      );

      expect(copy.id, '2');
      expect(copy.title, 'Updated');
      expect(copy.intent, MsgrSnackbarIntent.error);
      expect(copy.duration, const Duration(seconds: 10));
      expect(copy.body, 'World');
      expect(copy.actionLabel, 'Retry');
      expect(copy.metadata, {'traceId': 'abc'});
      expect(copy.hasAction, isTrue);
    });

    test('toMap serialises intent and duration', () {
      const message = MsgrSnackbarMessage(
        id: '3',
        title: 'Warning',
        intent: MsgrSnackbarIntent.warning,
        duration: Duration(milliseconds: 2500),
        metadata: {'reason': 'quota'},
      );

      final map = message.toMap();

      expect(map['intent'], 'warning');
      expect(map['durationMilliseconds'], 2500);
      expect(map['metadata'], {'reason': 'quota'});
    });

    test('fromMap parses unknown values gracefully', () {
      final message = MsgrSnackbarMessage.fromMap({
        'id': '4',
        'title': 'Fallback',
        'body': 'Body',
        'intent': 'unknown',
        'durationMilliseconds': 1500,
        'action_label': 'Dismiss',
        'metadata': {'source': 'test'},
      });

      expect(message.intent, MsgrSnackbarIntent.info);
      expect(message.duration, const Duration(milliseconds: 1500));
      expect(message.actionLabel, 'Dismiss');
      expect(message.body, 'Body');
      expect(message.metadata, {'source': 'test'});
      expect(message.hasAction, isTrue);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/features/chat/widgets/chat_composer.dart';

void main() {
  testWidgets('send button is disabled until the user types text',
      (tester) async {
    var sentMessages = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: ChatComposer(
            onSend: (_) => sentMessages++,
            isSending: false,
          ),
        ),
      ),
    );

    final sendButtonFinder = find.descendant(
      of: find.byType(ChatComposer),
      matching: find.byType(IconButton),
    );
    expect(sendButtonFinder, findsOneWidget);
    expect(tester.widget<IconButton>(sendButtonFinder).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Hei der');
    await tester.pumpAndSettle();

    expect(tester.widget<IconButton>(sendButtonFinder).onPressed, isNotNull);

    await tester.tap(sendButtonFinder);
    await tester.pump();

    expect(sentMessages, 1);
    expect(find.text('Hei der'), findsNothing);
  });

  testWidgets('send button shows progress indicator while sending',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: ChatComposer(
            onSend: _noop,
            isSending: true,
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(ChatComposer),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
  });
}

void _noop(String _) {}

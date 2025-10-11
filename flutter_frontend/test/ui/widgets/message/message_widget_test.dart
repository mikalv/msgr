import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/ui/widgets/message/message_widget.dart';

void main() {
  testWidgets('MessageWidget displays message content',
      (WidgetTester tester) async {
    // Mock data
    final message = MMessage.raw(
      fromProfileID: '123',
      content: 'Hello, world!',
      conversationID: 'conversation',
      roomID: 'room',
      createdAt: DateTime.parse('2023-10-01T12:00:00Z'),
      updatedAt: DateTime.parse('2023-10-01T12:05:00Z'),
      kIsSystemMsg: false,
      inReplyToMsgID: null,
    );

    // Build the widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageWidget(
            message: message,
            teamName: 'Test Team',
          ),
        ),
      ),
    );

    // Verify the message content is displayed
    expect(find.text('Hello, world!'), findsOneWidget);
    expect(find.text('2023-10-01T12:00:00.000Z'), findsOneWidget);
  });

  testWidgets('MessageWidget displays reaction icon',
      (WidgetTester tester) async {
    // Mock data
    final message = MMessage.raw(
      fromProfileID: '123',
      content: 'Hello, world!',
      conversationID: 'conversation',
      roomID: 'room',
      createdAt: DateTime.parse('2023-10-01T12:00:00Z'),
      updatedAt: DateTime.parse('2023-10-01T12:05:00Z'),
      kIsSystemMsg: false,
      inReplyToMsgID: null,
    );

    // Build the widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageWidget(
            message: message,
            teamName: 'Test Team',
          ),
        ),
      ),
    );

    // Verify the reaction icon is displayed
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('MessageWidget displays no reaction icon',
      (WidgetTester tester) async {
    // Mock data
    final message = MMessage.raw(
      fromProfileID: '123',
      content: 'Hello, world!',
      conversationID: 'conversation',
      roomID: 'room',
      createdAt: DateTime.parse('2023-10-01T12:00:00Z'),
      updatedAt: DateTime.parse('2023-10-01T12:05:00Z'),
      kIsSystemMsg: false,
      inReplyToMsgID: null,
    );

    // Build the widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageWidget(
            message: message,
            teamName: 'Test Team',
          ),
        ),
      ),
    );

    // Verify the no reaction icon is displayed
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });
}

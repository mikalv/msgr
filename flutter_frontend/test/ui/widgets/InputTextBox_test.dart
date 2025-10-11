import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/ui/widgets/InputTextBox.dart';

void main() {
  group('InputTextBox Widget Tests', () {
    testWidgets('renders InputTextBox with default values',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputTextBox(),
          ),
        ),
      );

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.byType(InputTextBox), findsOneWidget);
    });

    testWidgets('renders InputTextBox with custom hint text',
        (WidgetTester tester) async {
      const hintText = 'Enter your text here';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputTextBox(hinttext: hintText),
          ),
        ),
      );

      expect(find.text(hintText), findsOneWidget);
    });

    testWidgets('renders InputTextBox with obscure text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputTextBox(obscuretext: true),
          ),
        ),
      );

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('toggles obscure text visibility', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputTextBox(obscuretext: true),
          ),
        ),
      );

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('renders InputTextBox with prefix icon',
        (WidgetTester tester) async {
      const prefixIcon = Icon(Icons.email);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputTextBox(prefixIconbutton: prefixIcon),
          ),
        ),
      );

      expect(find.byIcon(Icons.email), findsOneWidget);
    });

    testWidgets('renders InputTextBox with suffix icon',
        (WidgetTester tester) async {
      const suffixIcon = Icon(Icons.check);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputTextBox(sufficIconbutton: suffixIcon),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('renders InputTextBox with custom border color',
        (WidgetTester tester) async {
      const borderColor = Colors.red;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputTextBox(boxbordercolor: borderColor),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, borderColor);
    });

    testWidgets('renders InputTextBox with custom background color',
        (WidgetTester tester) async {
      const backgroundColor = Colors.yellow;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputTextBox(boxbcgcolor: backgroundColor),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, backgroundColor);
    });
  });
}

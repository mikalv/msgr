import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/ui/widgets/custom_switch.dart';

void main() {
  testWidgets('CustomSwitch displays correct initial state',
      (WidgetTester tester) async {
    bool switchValue = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomSwitch(
            value: switchValue,
            onChanged: (value) {
              switchValue = value;
            },
          ),
        ),
      ),
    );

    // Verify initial state
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('On'), findsNothing);
  });

  testWidgets('CustomSwitch toggles state on tap', (WidgetTester tester) async {
    bool switchValue = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomSwitch(
            value: switchValue,
            onChanged: (value) {
              switchValue = value;
            },
          ),
        ),
      ),
    );

    // Tap the switch
    await tester.tap(find.byType(CustomSwitch));
    await tester.pumpAndSettle();

    // Verify state after tap
    expect(switchValue, isTrue);
    expect(find.text('On'), findsOneWidget);
    expect(find.text('Off'), findsNothing);
  });

  testWidgets('CustomSwitch displays correct colors and text',
      (WidgetTester tester) async {
    bool switchValue = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomSwitch(
            value: switchValue,
            onChanged: (value) {
              switchValue = value;
            },
            activeColor: Colors.green,
            inactiveColor: Colors.red,
            activeText: 'Active',
            inactiveText: 'Inactive',
          ),
        ),
      ),
    );

    // Verify initial colors and text
    expect(find.text('Inactive'), findsOneWidget);
    expect(find.text('Active'), findsNothing);
    expect((tester.firstWidget(find.byType(Container)) as Container).decoration,
        isA<BoxDecoration>().having((d) => d.color, 'color', Colors.red));

    // Tap the switch
    await tester.tap(find.byType(CustomSwitch));
    await tester.pumpAndSettle();

    // Verify colors and text after tap
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Inactive'), findsNothing);
    expect((tester.firstWidget(find.byType(Container)) as Container).decoration,
        isA<BoxDecoration>().having((d) => d.color, 'color', Colors.green));
  });

  testWidgets('CustomSwitch displays tooltips correctly',
      (WidgetTester tester) async {
    bool switchValue = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomSwitch(
            value: switchValue,
            onChanged: (value) {
              switchValue = value;
            },
            activeTooltip: 'Switch is ON',
            inactiveTooltip: 'Switch is OFF',
          ),
        ),
      ),
    );

    // Verify initial tooltip
    expect(find.byTooltip('Switch is OFF'), findsOneWidget);

    // Tap the switch
    await tester.tap(find.byType(CustomSwitch));
    await tester.pumpAndSettle();

    // Verify tooltip after tap
    expect(find.byTooltip('Switch is ON'), findsOneWidget);
  });
}

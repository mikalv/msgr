import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/ui/widgets/MobileInputWithOutline.dart';
import 'package:messngr/ui/widgets/PhoneField/intl_phone_field.dart';
import 'package:messngr/ui/widgets/PhoneField/phone_number.dart';

void main() {
  group('MobileInputWithOutline Widget Tests', () {
    testWidgets('should display hint text', (WidgetTester tester) async {
      const hintText = 'Enter your mobile number';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MobileInputWithOutline(
              hintText: hintText,
            ),
          ),
        ),
      );

      expect(find.text(hintText), findsOneWidget);
    });

    testWidgets('should call onSaved with phone number',
        (WidgetTester tester) async {
      PhoneNumber? savedPhoneNumber;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileInputWithOutline(
              onSaved: (phone) {
                savedPhoneNumber = phone;
              },
            ),
          ),
        ),
      );

      final phoneField = find.byType(IntlPhoneField);
      await tester.enterText(phoneField, '1234567890');
      await tester.pump();

      expect(savedPhoneNumber?.number, '1234567890');
    });

    testWidgets('should apply custom styles', (WidgetTester tester) async {
      const borderColor = Colors.red;
      const buttonTextColor = Colors.blue;
      const buttonhintTextColor = Colors.green;
      const hintStyle = TextStyle(color: Colors.purple);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MobileInputWithOutline(
              borderColor: borderColor,
              buttonTextColor: buttonTextColor,
              buttonhintTextColor: buttonhintTextColor,
              hintStyle: hintStyle,
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final boxDecoration = container.decoration as BoxDecoration;

      expect(boxDecoration.border?.top.color, borderColor);

      final intlPhoneField =
          tester.widget<IntlPhoneField>(find.byType(IntlPhoneField));
      expect(intlPhoneField.style?.color, buttonTextColor);
      expect(intlPhoneField.decoration?.hintStyle?.color, buttonhintTextColor);
      expect(intlPhoneField.decoration?.hintStyle, hintStyle);
    });
  });
}

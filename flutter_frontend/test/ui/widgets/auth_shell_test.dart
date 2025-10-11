import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/ui/widgets/auth/auth_shell.dart';

void main() {
  testWidgets('AuthShell displays provided sections', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthShell(
          title: 'Tittel',
          subtitle: 'Undertekst',
          illustration: SizedBox.shrink(),
          bulletPoints: ['Punkt 1', 'Punkt 2'],
          child: Text('Skjema'),
          footer: [Text('Fotnote')],
        ),
      ),
    );

    expect(find.text('Tittel'), findsOneWidget);
    expect(find.text('Undertekst'), findsOneWidget);
    expect(find.text('Skjema'), findsOneWidget);
    expect(find.text('Punkt 1'), findsOneWidget);
    expect(find.text('Punkt 2'), findsOneWidget);
    expect(find.text('Fotnote'), findsOneWidget);
  });
}

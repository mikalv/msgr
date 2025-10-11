import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/ui/widgets/snackbar/msgr_snackbar.dart';
import 'package:msgr_messages/msgr_messages.dart';

void main() {
  group('MsgrSnackBar', () {
    testWidgets('renders title, body and action with default theme',
        (tester) async {
      final message = MsgrSnackbarMessage(
        id: 'success',
        title: 'Alt lagret!',
        body: 'Vi synkroniserte meldingen med alle enheter.',
        intent: MsgrSnackbarIntent.success,
        actionLabel: 'Angre',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      context.showMsgrSnackBar(
                        message,
                        onAction: () {},
                      );
                    },
                    child: const Text('Vis snackbar'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Vis snackbar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Alt lagret!'), findsOneWidget);
      expect(
        find.text('Vi synkroniserte meldingen med alle enheter.'),
        findsOneWidget,
      );
      expect(find.text('Angre'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('applies theme overrides when provided', (tester) async {
      final baseTheme = MsgrSnackBarThemeData.standard();
      final customTheme = baseTheme.copyWith(
        margin: const EdgeInsets.all(24),
        intentThemes: {
          MsgrSnackbarIntent.error: baseTheme
              .resolveIntent(MsgrSnackbarIntent.error)
              .copyWith(icon: Icons.close_rounded),
        },
      );

      final message = MsgrSnackbarMessage(
        id: 'error',
        title: 'Kunne ikke lagre',
        intent: MsgrSnackbarIntent.error,
        actionLabel: 'Prøv igjen',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      context.showMsgrSnackBar(
                        message,
                        theme: customTheme,
                        onAction: () {},
                      );
                    },
                    child: const Text('Trigger'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final snackBarFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SnackBar && widget.margin == const EdgeInsets.all(24),
      );
      expect(snackBarFinder, findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.text('Prøv igjen'), findsOneWidget);
    });
  });
}

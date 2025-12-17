import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:core/config/AppNavigation.dart';
import 'package:core/services/app_localizations.dart';
import 'package:core/ui/screens/welcome_screen/onboarding.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Column(
      children: [
        const Expanded(child: OnboardingComponent()),
        Wrap(
          alignment: WrapAlignment.spaceAround,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                    child:
                        Text(AppLocalizations.of(context)!.translate('login')),
                    onPressed: () {
                      context.push(AppNavigation.registerPath);
                    }),
              ],
            )
          ],
        ),
      ],
    ));
  }
}

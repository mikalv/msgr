import 'package:flutter/material.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/navigation/navigation_actions.dart';
import 'package:messngr/services/app_localizations.dart';
import 'package:messngr/ui/screens/welcome_screen/onboarding.dart';
import 'package:messngr/utils/flutter_redux.dart';

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
                    child: Text(AppLocalizations.of(context)!.translate('login')),
                    onPressed: () {
                      StoreProvider.of<AppState>(context).dispatch(
                          NavigateToNewRouteAction(
                              route: AppNavigation.registerPath));
                    }),
              ],
            )
          ],
        ),
      ],
    ));
  }
}

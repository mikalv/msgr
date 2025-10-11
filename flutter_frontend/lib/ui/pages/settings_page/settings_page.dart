import 'package:flutter/material.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/authentication/auth_actions.dart';
import 'package:messngr/utils/flutter_redux.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                AppNavigation.router.go(
                  AppNavigation.loginPath,
                );
              },
              child: const Text('Go SignIn Page'),
            ),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Or instead we can launch the bottom navigation page(with shell) for different tab with only changing the path',
                textAlign: TextAlign.center,
              ),
            ),
            ElevatedButton(
              onPressed: () {
                AppNavigation.router.push(
                  AppNavigation.loginPath,
                );
              },
              child: const Text('Push SignIn Page'),
            ),
            ElevatedButton(
              onPressed: () async {
                StoreProvider.of<AppState>(context).dispatch(LogOutAction());
              },
              child: const Text('Logout'),
            ),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Or instead we can launch the bottom navigation page(with shell) for different tab with only changing the path',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

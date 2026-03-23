import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/config/theme.dart';
import 'package:core/providers/auth_state_provider.dart';
import 'package:core/providers/push_provider.dart';
import 'package:core/providers/unread_provider.dart';
import 'package:core/ui/auth/simple_login_screen.dart';
import 'package:core/ui/shell/app_shell.dart';
import 'package:core/ui/shell/chat/simple_chat_content.dart';

class IOSApp extends StatelessWidget {
  const IOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Messngr',
        debugShowCheckedModeBanner: false,
        theme: msgrDarkTheme,
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(simpleAuthProvider);

    if (!auth.isLoggedIn) {
      return SimpleLoginScreen(
        onLoginSuccess: () {},
      );
    }

    // Initialize push notifications when logged in
    final pushManager = ref.read(pushManagerProvider);
    Future.microtask(() => pushManager.init());

    return const AppShell(child: SimpleChatContent());
  }
}

ThemeData get msgrDarkTheme => ThemeData(
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1164A3),
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: const Color(0xFF1A1D21),
  useMaterial3: true,
);

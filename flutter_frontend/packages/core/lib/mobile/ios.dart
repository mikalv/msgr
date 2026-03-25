import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'package:core/config/theme.dart';
import 'package:core/providers/auth_state_provider.dart';
import 'package:core/providers/msgr_client_provider.dart';
import 'package:core/providers/deep_link_provider.dart';
import 'package:core/providers/push_provider.dart';
import 'package:core/providers/web_push_provider.dart';
import 'package:core/providers/team_list_provider.dart';
import 'package:core/providers/unread_provider.dart';
import 'package:core/ui/auth/profile_setup_screen.dart';
import 'package:core/ui/auth/simple_login_screen.dart';
import 'package:core/ui/shell/app_shell.dart';
import 'package:core/ui/shell/chat/simple_chat_content.dart';

import 'web_url_stub.dart' if (dart.library.html) 'web_url_web.dart' as webUrl;

final _log = Logger('IOSApp');

/// Extracts an invite code from the current web URL, if present.
/// Returns null on non-web platforms or if URL doesn't match /invite/:code.
String? _extractInviteCode() {
  if (!kIsWeb) return null;
  try {
    final uri = Uri.base;
    final segments = uri.pathSegments;
    if (segments.length == 2 && segments[0] == 'invite') {
      return segments[1];
    }
  } catch (_) {}
  return null;
}

/// Pending invite code from the URL (consumed after redemption).
String? _pendingInviteCode = _extractInviteCode();


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

class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  bool _redeemingInvite = false;
  bool _profileSetupDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tryRedeemInvite();
  }

  Future<void> _tryRedeemInvite() async {
    final code = _pendingInviteCode;
    if (code == null || _redeemingInvite) return;

    final auth = ref.read(simpleAuthProvider);
    if (!auth.isLoggedIn) return;

    setState(() => _redeemingInvite = true);
    _pendingInviteCode = null; // Consume

    try {
      final client = ref.read(msgrApiProvider);
      final result = await client.redeemInvite(code);
      final data = result['data'] ?? result;
      final teamSlug = data['team']?['slug'] as String?;

      _log.info('Invite redeemed: team=$teamSlug');

      // Refresh team list and select the new team
      await ref.read(teamListProvider.notifier).refresh();
      if (teamSlug != null) {
        final teams = ref.read(teamsProvider);
        final team = teams.where((t) => t.slug == teamSlug).firstOrNull;
        if (team != null) {
          ref.read(selectedTeamProvider.notifier).select(team);
        }
      }

      // Clear invite URL from browser address bar
      if (kIsWeb) {
        try { webUrl.replaceUrl('/'); } catch (_) {}
      }
    } catch (e) {
      _log.warning('Invite redemption failed: $e');
    }

    if (mounted) setState(() => _redeemingInvite = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(simpleAuthProvider);

    if (!auth.isLoggedIn) {
      return SimpleLoginScreen(
        onLoginSuccess: () => _tryRedeemInvite(),
      );
    }

    if (_redeemingInvite) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Joining team...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    // Profile setup gate — must set display name before entering app
    final needsProfile = !_profileSetupDone &&
        (auth.displayName == null || auth.displayName!.isEmpty || auth.displayName == auth.email);
    if (needsProfile) {
      return ProfileSetupScreen(
        onComplete: () => setState(() => _profileSetupDone = true),
      );
    }

    // Initialize push notifications when logged in
    final pushManager = ref.read(pushManagerProvider);
    Future.microtask(() => pushManager.init());
    // Initialize web push (no-op on native platforms)
    ref.read(webPushManagerProvider);
    // Initialize deep link listener (no-op on web)
    ref.read(deepLinkListenerProvider);

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

import 'package:flutter/material.dart';
import 'package:messngr/features/auth/auth_identity_store.dart';
import 'package:messngr/features/auth/dev_login_page.dart';
import 'package:messngr/services/api/chat_api.dart';
import 'package:provider/provider.dart';

class AuthSession {
  const AuthSession({required this.identity, required this.signOut});

  final AccountIdentity identity;
  final Future<void> Function() signOut;
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthIdentityStore _store = AuthIdentityStore.instance;
  AccountIdentity? _identity;
  String? _displayName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadIdentity();
  }

  Future<void> _loadIdentity() async {
    final identity = await _store.load();
    final displayName = await _store.displayName();
    if (!mounted) return;
    setState(() {
      _identity = identity;
      _displayName = displayName;
      _loading = false;
    });
  }

  Future<void> _handleSignedIn(AccountIdentity identity, String displayName) async {
    await _store.save(identity, displayName: displayName);
    if (!mounted) return;
    setState(() {
      _identity = identity;
      _displayName = displayName;
    });
  }

  Future<void> _handleSignOut() async {
    await _store.clear();
    if (!mounted) return;
    setState(() {
      _identity = null;
      _displayName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_identity == null) {
      return DevLoginPage(onSignedIn: _handleSignedIn);
    }

    final session = AuthSession(identity: _identity!, signOut: _handleSignOut);
    return MultiProvider(
      providers: [
        Provider<AuthSession>.value(value: session),
        Provider<AccountIdentity>.value(value: session.identity),
        Provider<String?>.value(value: _displayName),
      ],
      child: widget.child,
    );
  }
}

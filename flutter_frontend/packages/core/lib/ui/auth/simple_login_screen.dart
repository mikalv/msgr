import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/providers/auth_state_provider.dart';
import 'package:core/services/auth_service.dart';

/// Simple login screen for the header-based auth flow (dev.msgr.no).
///
/// Two-step OTP flow:
///   1. Enter email -> "Send kode"
///   2. Enter code -> "Logg inn"
class SimpleLoginScreen extends ConsumerStatefulWidget {
  const SimpleLoginScreen({super.key, this.onLoginSuccess});

  /// Called after successful login. If null, the provider change will
  /// trigger navigation via the router redirect.
  final VoidCallback? onLoginSuccess;

  @override
  ConsumerState<SimpleLoginScreen> createState() => _SimpleLoginScreenState();
}

class _SimpleLoginScreenState extends ConsumerState<SimpleLoginScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  String? _error;
  ChallengeResult? _challenge;
  String? _debugCode;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _requestChallenge() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Skriv inn e-postadresse');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final challenge = await _authService.requestChallenge(email);
      setState(() {
        _challenge = challenge;
        _debugCode = challenge.debugCode;
        _isLoading = false;
        // Auto-fill debug code in dev mode
        if (challenge.debugCode != null) {
          _codeController.text = challenge.debugCode!;
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _challenge == null) {
      setState(() => _error = 'Skriv inn koden');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = await _authService.verifyCode(_challenge!.id, code);

      // Store auth state
      ref.read(simpleAuthProvider.notifier).login(
            accountId: session.accountId,
            profileId: session.profileId,
            email: _emailController.text.trim(),
          );

      widget.onLoginSuccess?.call();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Messngr',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _challenge == null
                      ? 'Logg inn med e-post'
                      : 'Skriv inn koden sendt til ${_emailController.text}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Email field
                TextField(
                  controller: _emailController,
                  enabled: _challenge == null && !_isLoading,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'E-post',
                    labelStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF02ac88)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                  ),
                ),

                // Code field (shown after challenge)
                if (_challenge != null) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _codeController,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Kode',
                      labelStyle: const TextStyle(color: Colors.white54),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white24),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFF02ac88)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                    ),
                  ),
                  if (_debugCode != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Debug-kode: $_debugCode',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],

                // Error message
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 24),

                // Action button
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : (_challenge == null ? _requestChallenge : _verifyCode),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF02ac88),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: Colors.grey.shade700,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _challenge == null ? 'Send kode' : 'Logg inn',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                // Reset link
                if (_challenge != null)
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _challenge = null;
                              _debugCode = null;
                              _codeController.clear();
                              _error = null;
                            });
                          },
                    child: const Text(
                      'Bruk annen e-post',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

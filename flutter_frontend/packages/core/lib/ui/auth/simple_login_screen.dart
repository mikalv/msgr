import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/providers/auth_state_provider.dart';
import 'package:core/providers/msgr_client_provider.dart';
import 'package:libmsgr/api.dart';

class SimpleLoginScreen extends ConsumerStatefulWidget {
  const SimpleLoginScreen({super.key, this.onLoginSuccess});
  final VoidCallback? onLoginSuccess;

  @override
  ConsumerState<SimpleLoginScreen> createState() => _SimpleLoginScreenState();
}

class _SimpleLoginScreenState extends ConsumerState<SimpleLoginScreen> {
  final _identifierController = TextEditingController();
  final _codeController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  ChallengeResult? _challenge;
  String? _debugCode;
  bool _usePhone = false; // toggle between email and phone

  @override
  void dispose() {
    _identifierController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _channel => _usePhone ? 'phone' : 'email';

  Future<void> _requestChallenge() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      setState(() => _error = _usePhone ? 'Skriv inn telefonnummer' : 'Skriv inn e-postadresse');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final api = ref.read(msgrApiProvider);
      final challenge = await api.requestChallenge(identifier, channel: _channel);
      setState(() {
        _challenge = challenge;
        _debugCode = challenge.debugCode;
        _isLoading = false;
        if (challenge.debugCode != null) {
          _codeController.text = challenge.debugCode!;
        }
      });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Skriv inn kode');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final api = ref.read(msgrApiProvider);
      final session = await api.verifyCode(_challenge!.id, code);

      ref.read(simpleAuthProvider.notifier).login(
        accountId: session.accountId,
        profileId: session.profileId,
        email: session.email,
        displayName: session.displayName,
      );

      widget.onLoginSuccess?.call();
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
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
      fillColor: Colors.white.withValues(alpha: 0.05),
    );
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
                  style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _challenge == null
                      ? (_usePhone ? 'Logg inn med telefonnummer' : 'Logg inn med e-post')
                      : 'Skriv inn koden sendt til ${_challenge!.targetHint ?? _identifierController.text}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Identifier field (email or phone)
                TextField(
                  controller: _identifierController,
                  enabled: _challenge == null && !_isLoading,
                  autofocus: true,
                  keyboardType: _usePhone ? TextInputType.phone : TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(_usePhone ? 'Telefonnummer' : 'E-post'),
                  onSubmitted: _challenge == null ? (_) => _requestChallenge() : null,
                ),

                // Toggle email/phone
                if (_challenge == null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : () {
                        setState(() {
                          _usePhone = !_usePhone;
                          _identifierController.clear();
                          _error = null;
                        });
                      },
                      child: Text(
                        _usePhone ? 'Bruk e-post i stedet' : 'Bruk telefonnummer i stedet',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  ),

                // Code field
                if (_challenge != null) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _codeController,
                    enabled: !_isLoading,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Kode'),
                    onSubmitted: (_) => _verifyCode(),
                  ),
                  if (_debugCode != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Debug-kode: $_debugCode',
                        style: const TextStyle(color: Colors.amber, fontSize: 12)),
                    ),
                ],

                // Error
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      textAlign: TextAlign.center),
                  ),

                const SizedBox(height: 24),

                // Action button
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : (_challenge == null ? _requestChallenge : _verifyCode),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF02ac88),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      disabledBackgroundColor: Colors.grey.shade700,
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_challenge == null ? 'Send kode' : 'Logg inn',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),

                // Reset
                if (_challenge != null)
                  TextButton(
                    onPressed: _isLoading ? null : () {
                      setState(() { _challenge = null; _debugCode = null; _codeController.clear(); _error = null; });
                    },
                    child: Text('Bruk ${_usePhone ? "annet nummer" : "annen e-post"}',
                      style: const TextStyle(color: Colors.white54)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:messngr/config/backend_environment.dart';
import 'package:messngr/services/api/auth_api.dart';
import 'package:messngr/services/api/chat_api.dart' show AccountIdentity, ApiException;

class DevLoginResult {
  const DevLoginResult({
    required this.identity,
    required this.displayName,
    required this.noiseSessionId,
    required this.devicePrivateKey,
    required this.devicePublicKey,
  });

  final AccountIdentity identity;
  final String displayName;
  final String noiseSessionId;
  final String devicePrivateKey;
  final String devicePublicKey;
}

class DevLoginPage extends StatefulWidget {
  const DevLoginPage({super.key, required this.onSignedIn});

  final Future<void> Function(DevLoginResult result) onSignedIn;

  @override
  State<DevLoginPage> createState() => _DevLoginPageState();
}

class _DevLoginPageState extends State<DevLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _backendController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final backend = BackendEnvironment.instance.apiBaseUri;
    final host = backend.hasPort ? '${backend.host}:${backend.port}' : backend.host;
    _backendController.text = host;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _backendController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final displayName = _displayNameController.text.trim();
    final email = _emailController.text.trim();
    final backendOverride = _backendController.text.trim();

    if (!_applyBackendOverride(backendOverride)) {
      setState(() {
        _isSubmitting = false;
      });
      return;
    }

    try {
      final authApi = AuthApi();
      final handshake = await authApi.createDevHandshake();

      final usableEmail = email.isNotEmpty ? email : _generateEmail(displayName);

      final challenge = await authApi.requestEmailChallenge(
        email: usableEmail,
        deviceKey: handshake.deviceKey,
      );

      final code = await _resolveOtpCode(challenge);
      if (code == null) {
        setState(() {
          _error = 'Ingen OTP-kode ble oppgitt.';
        });
        return;
      }

      final session = await authApi.verifyCode(
        challengeId: challenge.id,
        code: code,
        noiseSessionId: handshake.sessionId,
        noiseSignature: handshake.signature,
        displayName: displayName,
      );

      final identity = AccountIdentity(
        accountId: session.accountId,
        profileId: session.profileId,
        noiseToken: session.noiseToken,
        noiseSessionId: session.noiseSessionId,
      );

      await widget.onSignedIn(
        DevLoginResult(
          identity: identity,
          displayName: displayName,
          noiseSessionId: session.noiseSessionId,
          devicePrivateKey: handshake.devicePrivateKey,
          devicePublicKey: handshake.deviceKey,
        ),
      );
    } on ApiException catch (error) {
      setState(() {
        _error = 'Kunne ikke fullføre innlogging (${error.statusCode}).';
      });
    } catch (error) {
      setState(() {
        _error = 'Noe gikk galt: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _generateEmail(String displayName) {
    final slug = displayName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '.')
        .replaceAll(RegExp(r'\.+'), '.')
        .trim()
        .replaceAll(RegExp(r'^\.|\.$'), '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeSlug = slug.isEmpty ? 'bruker' : slug;
    return '$safeSlug+$timestamp@dev.msgr.local';
  }

  Future<String?> _resolveOtpCode(OtpChallenge challenge) async {
    if (challenge.debugCode != null && challenge.debugCode!.isNotEmpty) {
      return challenge.debugCode;
    }
    return _promptForOtpCode();
  }

  Future<String?> _promptForOtpCode() async {
    final controller = TextEditingController();
    String? result;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('OTP-kode'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Skriv inn koden fra e-post eller SMS',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Avbryt'),
            ),
            FilledButton(
              onPressed: () {
                result = controller.text.trim();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Bekreft'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result?.isEmpty ?? true ? null : result;
  }

  bool _applyBackendOverride(String raw) {
    if (raw.isEmpty) {
      return true;
    }

    final parsed = _parseBackendInput(raw);
    if (parsed == null) {
      setState(() {
        _error = 'Ugyldig backend-adresse: "$raw"';
      });
      return false;
    }

    BackendEnvironment.instance.override(
      scheme: parsed.scheme,
      host: parsed.host,
      port: parsed.port,
    );
    return true;
  }

  _BackendOverride? _parseBackendInput(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (trimmed.contains('://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null || uri.host.isEmpty) {
        return null;
      }
      return _BackendOverride(
        scheme: uri.scheme.isNotEmpty ? uri.scheme : null,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
      );
    }

    final parts = trimmed.split(':');
    final host = parts.first.trim();
    if (host.isEmpty) {
      return null;
    }

    int? port;
    if (parts.length > 1) {
      final portCandidate = parts.sublist(1).join(':');
      port = int.tryParse(portCandidate);
      if (port == null) {
        return null;
      }
    }

    return _BackendOverride(host: host, port: port);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 8,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Logg inn med OTP',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Vi lager en ny profil eller gjenbruker eksisterende konto via OTP. '
                      'I dev returnerer backenden koden i klartekst.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _displayNameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Navn',
                        hintText: 'Kari Nordmann',
                      ),
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'Navn er påkrevd';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-post (valgfri – brukes for OTP)',
                        hintText: 'kari@example.com',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _backendController,
                      decoration: const InputDecoration(
                        labelText: 'Backend-host (valgfri)',
                        hintText: '10.0.2.2:4000 eller https://dev.msgr.no',
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Logg inn'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackendOverride {
  const _BackendOverride({this.scheme, required this.host, this.port});

  final String? scheme;
  final String host;
  final int? port;
}

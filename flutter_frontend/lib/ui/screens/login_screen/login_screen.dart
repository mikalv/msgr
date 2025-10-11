import 'dart:async';

import 'package:flutter/material.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/utils/flutter_redux.dart';
import 'package:libmsgr/libmsgr.dart';

import '../../../redux/app_state.dart';
import '../../../redux/authentication/auth_actions.dart';

enum _LoginMethod { email, phone }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _methodNotifier = ValueNotifier<_LoginMethod>(_LoginMethod.phone);

  late final RegistrationService _registrationService;

  @override
  void initState() {
    super.initState();
    _registrationService = RegistrationService();
    _registrationService.maybeRegisterDevice();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _displayNameController.dispose();
    _methodNotifier.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    final store = StoreProvider.of<AppState>(context);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final completer = Completer<AuthChallenge?>();

    switch (_methodNotifier.value) {
      case _LoginMethod.email:
        store.dispatch(RequestCodeEmailAction(
          email: _emailController.text.trim(),
          displayName: _displayNameController.text.trim().isEmpty
              ? null
              : _displayNameController.text.trim(),
          completer: completer,
        ));
        break;
      case _LoginMethod.phone:
        store.dispatch(RequestCodeMsisdnAction(
          msisdn: _phoneController.text.trim(),
          displayName: _displayNameController.text.trim().isEmpty
              ? null
              : _displayNameController.text.trim(),
          completer: completer,
        ));
        break;
    }

    try {
      await completer.future;
      if (!mounted) return;
      AppNavigation.router.push(AppNavigation.loginCodePath);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kunne ikke sende kode: $error')),
      );
    }
  }

  Widget _buildInputField() {
    switch (_methodNotifier.value) {
      case _LoginMethod.email:
        return TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'E-post',
            prefixIcon: Icon(Icons.alternate_email_rounded),
          ),
          validator: (value) {
            final trimmed = value?.trim() ?? '';
            if (trimmed.isEmpty) {
              return 'Skriv inn e-postadressen din';
            }
            if (!trimmed.contains('@')) {
              return 'Dette ser ikke ut som en gyldig e-post';
            }
            return null;
          },
        );
      case _LoginMethod.phone:
        return TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Mobilnummer',
            prefixIcon: Icon(Icons.phone_android_rounded),
            helperText: 'Inkluder landskode, f.eks. +47',
          ),
          validator: (value) {
            final trimmed = value?.trim() ?? '';
            if (trimmed.isEmpty) {
              return 'Skriv inn mobilnummeret ditt';
            }
            if (!trimmed.startsWith('+') || trimmed.length < 8) {
              return 'Bruk internasjonalt format (+47...)';
            }
            return null;
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1F1C2C), Color(0xFF928DAB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 16,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                  child: ValueListenableBuilder<_LoginMethod>(
                    valueListenable: _methodNotifier,
                    builder: (context, method, _) {
                      return Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(Icons.forum_rounded,
                                size: 48, color: Color(0xFF4F46E5)),
                            const SizedBox(height: 16),
                            const Text(
                              'Velkommen tilbake!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Logg inn med e-post eller mobilnummer for å fortsette praten.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            SegmentedButton<_LoginMethod>(
                              segments: const [
                                ButtonSegment(
                                  value: _LoginMethod.phone,
                                  label: Text('Mobil'),
                                  icon: Icon(Icons.phone_rounded),
                                ),
                                ButtonSegment(
                                  value: _LoginMethod.email,
                                  label: Text('E-post'),
                                  icon: Icon(Icons.email_rounded),
                                ),
                              ],
                              style: ButtonStyle(
                                shape: WidgetStateProperty.all(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                              selected: {method},
                              onSelectionChanged: (selection) {
                                _methodNotifier.value = selection.first;
                              },
                            ),
                            const SizedBox(height: 24),
                            _buildInputField(),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _displayNameController,
                              decoration: const InputDecoration(
                                labelText: 'Navn (valgfritt)',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () => _submit(context),
                                child: const Text('Send engangskode'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: () async {
                                final store =
                                    StoreProvider.of<AppState>(context);
                                final user = await _registrationService.completeOidc(
                                  provider: 'preview',
                                  subject: 'local-user',
                                  email: _emailController.text.trim().isEmpty
                                      ? null
                                      : _emailController.text.trim(),
                                  name: _displayNameController.text.trim().isEmpty
                                      ? null
                                      : _displayNameController.text.trim(),
                                );
                                if (!mounted) return;
                                if (user == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Kunne ikke fullføre OIDC akkurat nå'),
                                    ),
                                  );
                                } else {
                                  store.dispatch(OnAuthenticatedAction(user: user));
                                  final teamCompleter = Completer();
                                  store.dispatch(ListMyTeamsRequestAction(
                                      accessToken: user.accessToken,
                                      completer: teamCompleter));
                                  try {
                                    await teamCompleter.future;
                                    if (!mounted) return;
                                    AppNavigation.router
                                        .push(AppNavigation.selectTeamPath);
                                  } catch (error) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Klarte ikke hente team: $error'),
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.verified_user_outlined),
                              label: const Text('Fortsett med OIDC'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/providers/auth_provider.dart';
import 'package:libmsgr/libmsgr.dart';

import '../../widgets/auth/auth_input_decoration.dart';
import '../../widgets/auth/auth_shell.dart';

enum _LoginMethod { email, phone }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      AuthChallenge? challenge;

      switch (_methodNotifier.value) {
        case _LoginMethod.email:
          final email = _emailController.text.trim();
          final displayName = _displayNameController.text.trim().isEmpty
              ? null
              : _displayNameController.text.trim();

          // TODO: Implement proper email auth via authProvider
          challenge = await _registrationService.requestForSignInCodeEmail(email);

          ref.read(authProvider.notifier).setPendingData(
            email: email,
            displayName: displayName,
            challengeId: challenge?.id,
            channel: 'email',
          );
          break;

        case _LoginMethod.phone:
          final msisdn = _phoneController.text.trim();
          final displayName = _displayNameController.text.trim().isEmpty
              ? null
              : _displayNameController.text.trim();

          // TODO: Implement proper phone auth via authProvider
          challenge = await _registrationService.requestForSignInCodeMsisdn(msisdn);

          ref.read(authProvider.notifier).setPendingData(
            msisdn: msisdn,
            displayName: displayName,
            challengeId: challenge?.id,
            channel: 'sms',
          );
          break;
      }

      if (!mounted) return;
      AppNavigation.router.push(AppNavigation.loginCodePath);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kunne ikke sende kode: $error')),
      );
    }
  }

  Widget _buildInputField(BuildContext context) {
    switch (_methodNotifier.value) {
      case _LoginMethod.email:
        return TextFormField(
          controller: _emailController,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          keyboardType: TextInputType.emailAddress,
          decoration: authInputDecoration(
            context,
            label: 'E-post',
            icon: Icons.alternate_email_rounded,
            hintText: 'navn@domene.no',
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
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          keyboardType: TextInputType.phone,
          decoration: authInputDecoration(
            context,
            label: 'Mobilnummer',
            icon: Icons.phone_android_rounded,
            helperText: 'Inkluder landskode, f.eks. +47',
            hintText: '+47 123 45 678',
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
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF6366F1),
      foregroundColor: Colors.white,
      textStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
    );

    return AuthShell(
      icon: Icons.forum_rounded,
      title: 'Velkommen tilbake!',
      subtitle:
          'Logg inn med e-post eller mobilnummer for å fortsette praten med teamet ditt.',
      illustrationAsset: 'assets/images/welcome/paperplane.png',
      bulletPoints: const [
        'Rask tilgang til pågående samtaler og team.',
        'Sikker autentisering med engangskoder.',
        'Sømløst bytte mellom e-post og mobilnummer.',
      ],
      child: ValueListenableBuilder<_LoginMethod>(
        valueListenable: _methodNotifier,
        builder: (context, method, _) {
          return Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                      icon: Icon(Icons.alternate_email_outlined),
                    ),
                  ],
                  showSelectedIcon: false,
                  selected: {method},
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white.withOpacity(0.18);
                      }
                      return Colors.white.withOpacity(0.04);
                    }),
                    foregroundColor: WidgetStateProperty.all(Colors.white),
                    side: WidgetStateProperty.resolveWith((states) {
                      return BorderSide(
                        color: states.contains(WidgetState.selected)
                            ? Colors.transparent
                            : Colors.white.withOpacity(0.12),
                      );
                    }),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    ),
                  ),
                  onSelectionChanged: (selection) {
                    _methodNotifier.value = selection.first;
                  },
                ),
                const SizedBox(height: 24),
                _buildInputField(context),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _displayNameController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: authInputDecoration(
                    context,
                    label: 'Navn (valgfritt)',
                    icon: Icons.person_outline,
                    hintText: 'Visningsnavn i chatten',
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  style: buttonStyle,
                  onPressed: () => _submit(context),
                  child: const Text('Send engangskode'),
                ),
              ],
            ),
          );
        },
      ),
      footer: [
        TextButton.icon(
          onPressed: () async {
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
                  content: Text('Kunne ikke fullføre OIDC akkurat nå'),
                ),
              );
            } else {
              // TODO: Implement proper OIDC flow in authProvider
              // For now, navigate to team selection
              // ref.read(authProvider.notifier).setCurrentUser(user);
              try {
                // Fetch teams (TODO: implement in provider)
                if (!mounted) return;
                AppNavigation.router.push(AppNavigation.selectTeamPath);
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Klarte ikke hente team: $error'),
                  ),
                );
              }
            }
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.white70,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('Fortsett med OIDC'),
        ),
        const SizedBox(height: 8),
        const Text(
          'OIDC er tilgjengelig for forhåndsvisningsbrukere.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:messngr/ui/widgets/auth/auth_shell.dart';
import 'package:messngr/ui/widgets/pinput_login_code.dart';

class RegisterCodeScreen extends StatelessWidget {
  const RegisterCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      icon: Icons.verified_user_rounded,
      title: 'Bekreft koden din',
      subtitle:
          'Skriv inn engangskoden vi sendte, så oppretter vi kontoen din på et blunk.',
      illustrationAsset: 'assets/images/welcome/encryption.png',
      bulletPoints: const [
        'Koden er personlig og deles ikke med andre.',
        'Når den er godkjent, er kontoen din klar til bruk.',
      ],
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 8),
          PinputLoginCode(),
        ],
      ),
    );
  }
}

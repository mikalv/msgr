import 'package:flutter/material.dart';
import 'package:messngr/ui/widgets/auth/auth_shell.dart';
import 'package:messngr/ui/widgets/pinput_login_code.dart';

class CodeScreen extends StatelessWidget {
  const CodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      icon: Icons.lock_clock_rounded,
      title: 'Skriv inn engangskoden',
      subtitle:
          'Koden ble sendt til kontaktpunktet du valgte. Den utløper snart, så legg den inn med en gang.',
      illustrationAsset: 'assets/images/welcome/key.png',
      bulletPoints: const [
        'Hold koden hemmelig – del den aldri med andre.',
        'Du kan be om en ny kode hvis denne utløper.',
      ],
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 8),
          PinputLoginCode(),
        ],
      ),
      footer: const [
        Text(
          'Sjekk søppelposten eller vent et øyeblikk om koden ikke har kommet ennå.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38),
        ),
      ],
    );
  }
}

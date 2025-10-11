import 'package:flutter/material.dart';
import 'package:messngr/ui/widgets/pinput_login_code.dart';

class RegisterCodeScreen extends StatefulWidget {
  const RegisterCodeScreen({super.key});

  @override
  State<RegisterCodeScreen> createState() => _RegisterCodeScreenState();
}

class _RegisterCodeScreenState extends State<RegisterCodeScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
        body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [PinputLoginCode()],
      ),
    ));
  }
}

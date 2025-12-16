import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/authentication/auth_actions.dart';
import 'package:messngr/redux/navigation/navigation_actions.dart';
import 'package:messngr/ui/widgets/MobileInputWithOutline.dart';
import 'package:messngr/ui/widgets/PhoneField/phone_number.dart';
import 'package:messngr/ui/widgets/PhoneField/countries.dart';
import 'package:messngr/ui/widgets/auth/auth_input_decoration.dart';
import 'package:messngr/ui/widgets/auth/auth_shell.dart';
import 'package:messngr/utils/flutter_redux.dart';

class RegisterUserScreen extends StatefulWidget {
  const RegisterUserScreen({super.key});

  @override
  State<RegisterUserScreen> createState() => _RegisterUserScreenState();
}

class _RegisterUserScreenState extends State<RegisterUserScreen> {
  final Logger _log = Logger('_RegisterUserScreenState');
  final _msisdnFieldCtrl = TextEditingController();
  final _emailFieldCtrl = TextEditingController();
  final _displayNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool useMsisdnForAuth = true;
  bool _canSubmit = false;
  PhoneNumber? _phone;

  @override
  void initState() {
    super.initState();
    _emailFieldCtrl.addListener(_handleEmailChanged);
  }

  @override
  void dispose() {
    _emailFieldCtrl.removeListener(_handleEmailChanged);
    _msisdnFieldCtrl.dispose();
    _emailFieldCtrl.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _handleEmailChanged() {
    if (!mounted || useMsisdnForAuth) {
      return;
    }
    final isValid = _validateEmail(_emailFieldCtrl.text) == null;
    if (isValid != _canSubmit) {
      setState(() {
        _canSubmit = isValid;
      });
    }
  }

  void _updatePhone(PhoneNumber? phone) {
    setState(() {
      _phone = phone;
      _canSubmit = useMsisdnForAuth && _isValidPhone(phone);
    });
  }

  bool _isValidPhone(PhoneNumber? phone) {
    if (phone == null) {
      return false;
    }
    final raw = phone.number?.trim() ?? '';
    final dialCode = phone.countryCode?.trim() ?? '';
    if (raw.isEmpty || dialCode.isEmpty) {
      return false;
    }
    final expectedLength = _countryMaxLength(phone.countryISOCode);
    if (expectedLength != null) {
      return raw.length == expectedLength;
    }
    return raw.length >= 6;
  }

  int? _countryMaxLength(String? isoCode) {
    if (isoCode == null) {
      return null;
    }
    for (final country in countries) {
      if (country['code'] == isoCode) {
        final value = country['max_length'];
        if (value is int) {
          return value;
        }
        if (value is String) {
          return int.tryParse(value);
        }
      }
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Skriv inn e-postadressen din';
    }
    const pattern =
        r'''(?:[a-z0-9!#\$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#\$%&'*+/=?^_`{|}~-]+)*|
(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*)
@
(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[
(?:(?:(2(5[0-5]|[0-4][0-9])|1[0-9][0-9]|[1-9]?[0-9]))\.){3}
(?:(2(5[0-5]|[0-4][0-9])|1[0-9][0-9]|[1-9]?[0-9])|
[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x5e-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)
\])''';
    final regex = RegExp(pattern);
    if (!regex.hasMatch(trimmed)) {
      return 'Oppgi en gyldig e-postadresse';
    }
    return null;
  }

  Future<void> sendLoginRequest(BuildContext context) async {
    FocusScope.of(context).unfocus();
    if (!useMsisdnForAuth && !_formKey.currentState!.validate()) {
      return;
    }
    if (useMsisdnForAuth && !_isValidPhone(_phone)) {
      return;
    }

    final completer = Completer();
    final displayName = _displayNameController.text.trim().isEmpty
        ? null
        : _displayNameController.text.trim();

    if (useMsisdnForAuth) {
      final phoneNumber = _phone!.completeNumber;
      _log.info('Requesting login for number $phoneNumber');
      StoreProvider.of<AppState>(context).dispatch(RequestCodeMsisdnAction(
        msisdn: phoneNumber,
        displayName: displayName,
        completer: completer,
      ));
    } else {
      final email = _emailFieldCtrl.text.trim();
      _log.info('Requesting login for email $email');
      StoreProvider.of<AppState>(context).dispatch(RequestCodeEmailAction(
        email: email,
        displayName: displayName,
        completer: completer,
      ));
    }

    try {
      await completer.future;
      if (!mounted) return;
      StoreProvider.of<AppState>(context).dispatch(
          NavigateToNewRouteAction(route: AppNavigation.registerCodePath));
    } catch (error, stackTrace) {
      _log.severe(error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kunne ikke sende kode: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF22D3EE),
      foregroundColor: Colors.black,
      disabledBackgroundColor: Colors.white.withOpacity(0.08),
      disabledForegroundColor: Colors.white38,
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    );

    return AuthShell(
      icon: Icons.person_add_alt_rounded,
      title: 'Lag din msgr-konto',
      subtitle:
          'Velg hvordan du vil motta engangskoden din og bli med i samtalene på sekunder.',
      illustrationAsset: 'assets/images/welcome/route_path.png',
      bulletPoints: const [
        'Tilpass innloggingen til din arbeidsflyt.',
        'Sikker engangskode levert via e-post eller SMS.',
        'Perfekt for team og organisasjoner i vekst.',
      ],
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Mobil'),
                  icon: Icon(Icons.smartphone_rounded),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('E-post'),
                  icon: Icon(Icons.alternate_email_rounded),
                ),
              ],
              showSelectedIcon: false,
              selected: {useMsisdnForAuth},
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white.withOpacity(0.2);
                  }
                  return Colors.white.withOpacity(0.05);
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
                setState(() {
                  useMsisdnForAuth = selection.first;
                  if (useMsisdnForAuth) {
                    _canSubmit = _isValidPhone(_phone);
                  } else {
                    _canSubmit = _validateEmail(_emailFieldCtrl.text) == null;
                  }
                });
              },
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: useMsisdnForAuth
                  ? _buildPhoneInput(context)
                  : _buildEmailInput(context),
            ),
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
                icon: Icons.badge_outlined,
                hintText: 'Visningsnavn i teamet ditt',
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              style: buttonStyle,
              onPressed: _canSubmit ? () => sendLoginRequest(context) : null,
              child: const Text('Send engangskode'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Vi sender deg en kode som bekrefter identiteten din. Den er gyldig i noen få minutter.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.4),
            ),
          ],
        ),
      ),
      footer: const [
        Text(
          'Har du allerede en konto? Gå tilbake og logg inn.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38),
        ),
      ],
    );
  }

  Widget _buildPhoneInput(BuildContext context) {
    return SizedBox(
      key: const ValueKey('phone-input'),
      child: MobileInputWithOutline(
        width: double.infinity,
        controller: _msisdnFieldCtrl,
        initialCountryCode: DEFAULT_COUNTTRYCODE_ISO,
        autofocus: false,
        borderColor: Colors.white.withOpacity(0.16),
        borderWidth: 1.2,
        backgroundColor: Colors.white.withOpacity(0.05),
        fillColor: Colors.white.withOpacity(0.05),
        buttonTextColor: Colors.white,
        buttonhintTextColor: Colors.white60,
        hintStyle: const TextStyle(
          letterSpacing: 0.8,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: Colors.white54,
        ),
        textStyle: const TextStyle(
          height: 1.35,
          letterSpacing: 0.5,
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        onSaved: _updatePhone,
        onSubmitted: (_) {
          if (_canSubmit) {
            sendLoginRequest(context);
          }
        },
      ),
    );
  }

  Widget _buildEmailInput(BuildContext context) {
    return TextFormField(
      key: const ValueKey('email-input'),
      controller: _emailFieldCtrl,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      decoration: authInputDecoration(
        context,
        label: 'E-post',
        icon: Icons.alternate_email,
        hintText: 'navn@domene.no',
      ),
      keyboardType: TextInputType.emailAddress,
      validator: _validateEmail,
      onFieldSubmitted: (_) {
        if (_canSubmit) {
          sendLoginRequest(context);
        }
      },
    );
  }
}

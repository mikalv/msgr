import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/config/themedata.dart';
import 'package:messngr/providers/auth_provider.dart';
import 'package:messngr/providers/team_provider.dart';
import 'package:messngr/ui/widgets/MobileInputWithOutline.dart';
import 'package:messngr/ui/widgets/custom_switch.dart';

class InvitePage extends ConsumerStatefulWidget {
  const InvitePage({super.key});

  @override
  ConsumerState<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends ConsumerState<InvitePage> {
  final Logger _log = Logger('_InvitePageState');
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _msisdnFieldCtrl = TextEditingController();
  final _emailFieldCtrl = TextEditingController();
  bool useMsisdnForInvitation = true;
  bool allowUserToContinue = false;
  String? phoneNumber;

  @override
  void dispose() {
    _emailFieldCtrl.dispose();
    super.dispose();
  }

  Future<void> _inviteTeammate(BuildContext context) async {
    final authState = ref.read(authProvider);
    final currentTeam = authState.currentTeam;
    final currentProfile = authState.currentProfile;

    if (currentTeam == null || currentProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a team first')),
      );
      return;
    }

    final identifier = useMsisdnForInvitation ? phoneNumber! : _emailFieldCtrl.text;

    try {
      await ref.read(teamProvider.notifier).inviteUser(
        teamName: currentTeam.name,
        profileId: currentProfile.id,
        identifier: identifier,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation sent successfully')),
      );

      context.go(AppNavigation.homePath);
    } catch (error) {
      _log.severe('Failed to send invitation', error);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send invitation: $error')),
      );
    }
  }

  String? validateEmail(String? value) {
    const pattern = r"(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'"
        r'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-'
        r'\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*'
        r'[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:(2(5[0-5]|[0-4]'
        r'[0-9])|1[0-9][0-9]|[1-9]?[0-9]))\.){3}(?:(2(5[0-5]|[0-4][0-9])|1[0-9]'
        r'[0-9]|[1-9]?[0-9])|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\'
        r'x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])';
    final regex = RegExp(pattern);

    return value!.isNotEmpty && !regex.hasMatch(value)
        ? 'Enter a valid email address'
        : null;
  }

  Widget inputWidget() {
    return (useMsisdnForInvitation)
        ? MobileInputWithOutline(
            borderColor: borderColor,
            controller: _msisdnFieldCtrl,
            initialCountryCode: DEFAULT_COUNTTRYCODE_ISO,
            width: 300,
            onSaved: (phone) {
              var phoneCode = phone!.countryCode;
              var number = phone.number;
              phoneNumber = '$phoneCode$number';
              allowUserToContinue = true; // TODO: Do this better.
            },
          )
        : SizedBox(
            width: 300,
            child: Form(
              autovalidateMode: AutovalidateMode.always,
              child: TextFormField(
                  validator: (str) {
                    final invalid = validateEmail(str);
                    _log.info('Validator status: $invalid');
                    if (invalid == null) {
                      allowUserToContinue = true;
                    } else {
                      allowUserToContinue = false;
                    }
                    return invalid;
                  },
                  controller: _emailFieldCtrl,
                  style: formTextStyle,
                  decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'me@domain.com',
                      hintTextDirection: TextDirection.ltr,
                      hintStyle: formHintTextStyle,
                      focusedBorder: borderStyle,
                      enabledBorder: borderStyle,
                      errorBorder: borderStyle,
                      disabledBorder: borderStyle,
                      fillColor: Colors.white,
                      filled: true,
                      focusColor: Colors.white,
                      hoverColor: Colors.white,
                      border: borderStyle)),
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.go(AppNavigation.dashboardPath),
        ),
        title: const Text('Invite Teammates'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CustomSwitch(
                  activeText: 'Phone',
                  activeTooltip: 'Use phone number to authenticate',
                  inactiveText: 'Email',
                  inactiveTooltip: 'Use email to authenticate',
                  value: useMsisdnForInvitation,
                  activeColor: Colors.deepPurple,
                  inactiveColor: Colors.deepPurple,
                  onChanged: (value) {
                    setState(() {
                      useMsisdnForInvitation = value;
                    });
                  },
                ),
                inputWidget(),
                const SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: () => _inviteTeammate(context),
                  child: const Text('Send Invitation'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

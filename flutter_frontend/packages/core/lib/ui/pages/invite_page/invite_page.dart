import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/config/themedata.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/invitation/invitation_actions.dart';
import 'package:messngr/redux/navigation/navigation_actions.dart';
import 'package:messngr/ui/widgets/MobileInputWithOutline.dart';
import 'package:messngr/ui/widgets/custom_switch.dart';
import 'package:messngr/utils/flutter_redux.dart';

class InvitePage extends StatefulWidget {
  const InvitePage({super.key});

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
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

  _inviteTeammate(context) {
    return () {
      final store = StoreProvider.of<AppState>(context);
      if (useMsisdnForInvitation) {
        store.dispatch(InviteUserToTeamAction(
            identifier: phoneNumber!,
            teamName: store.state.teamState!.selectedTeam!.name));
      } else {
        store.dispatch(InviteUserToTeamAction(
            identifier: _emailFieldCtrl.text,
            teamName: store.state.teamState!.selectedTeam!.name));
      }
      store.dispatch(NavigateShellToNewRouteAction(
          route: AppNavigation.homePath, kRouteDoPopInstead: true));
    };
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
    final store = StoreProvider.of<AppState>(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => store.dispatch(NavigateShellToNewRouteAction(
              route: AppNavigation.dashboardPath)),
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
                  onPressed: _inviteTeammate(context),
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

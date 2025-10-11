import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/config/color_n_styles.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/authentication/auth_actions.dart';
import 'package:messngr/redux/navigation/navigation_actions.dart';
import 'package:messngr/ui/widgets/MobileInputWithOutline.dart';
import 'package:messngr/ui/widgets/custom_switch.dart';
import 'package:messngr/utils/flutter_redux.dart';

class RegisterUserScreen extends StatefulWidget {
  const RegisterUserScreen({super.key});

  @override
  State<RegisterUserScreen> createState() => _RegisterUserScreenState();
}

Widget headers({required String head, bool isSelect = true}) {
  return Container(
    height: isSelect == true ? 50 : 40,
    width: isSelect == true ? 120 : 110,
    alignment: Alignment.center,
    decoration: BoxDecoration(
        color: isSelect == true
            ? AppColors.white
            : AppColors.white.withOpacity(.98),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          isSelect == false
              ? const BoxShadow(color: Color.fromARGB(255, 58, 72, 226))
              : BoxShadow(
                  color: AppColors.black.withOpacity(.1),
                  offset: const Offset(0, -1),
                  blurRadius: 2,
                )
        ]),
    child: Text(
      head,
      style: isSelect == true
          ? AppStyles.medium()
          : AppStyles.light(color: AppColors.black.withOpacity(.7)),
    ),
  );
}

class _RegisterUserScreenState extends State<RegisterUserScreen> {
  final Logger _log = Logger('_RegisterUserScreenState');
  final _msisdnFieldCtrl = TextEditingController();
  final _emailFieldCtrl = TextEditingController();
  String? phoneCode = DEFAULT_COUNTTRYCODE_NUMBER;
  late String phoneNumber;
  bool useMsisdnForAuth = true;
  bool allowUserToContinue = false;

  @override
  void initState() {
    super.initState();
  }

  sendLoginRequest(context) async {
    final completer = Completer();
    completer.future.then((val) {
      StoreProvider.of<AppState>(context).dispatch(
          NavigateToNewRouteAction(route: AppNavigation.registerCodePath));
    }).catchError((error) {
      _log.severe(error);
    });
    if (useMsisdnForAuth) {
      _log.info('Requesting login for number $phoneNumber');
      StoreProvider.of<AppState>(context).dispatch(
          RequestCodeMsisdnAction(msisdn: phoneNumber, completer: completer));
    } else {
      var email = _emailFieldCtrl.text;
      _log.info('Requesting login for email $email');
      StoreProvider.of<AppState>(context)
          .dispatch(RequestCodeEmailAction(email: email, completer: completer));
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

  @override
  Widget build(BuildContext context) {
    // TODO: Make the email TextFormField be as alike to MobileInputWithOutline as possible
    // TODO: Figure out the blinking on focus/unfocus of the email TextFormField
    final borderColor = messngrGrey.withOpacity(0.2);
    final borderStyle = OutlineInputBorder(
      borderRadius: const BorderRadius.all(
        Radius.circular(10.0),
      ),
      borderSide: BorderSide(color: borderColor, width: 0.0),
    );
    Widget inputWidget = (useMsisdnForAuth)
        ? MobileInputWithOutline(
            borderColor: borderColor,
            controller: _msisdnFieldCtrl,
            initialCountryCode: DEFAULT_COUNTTRYCODE_ISO,
            onSubmitted: (msisdn) => {
                      if (allowUserToContinue) {sendLoginRequest(context)}
                    },
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
                  style: const TextStyle(
                      height: 1.35,
                      letterSpacing: 1,
                      fontSize: 16.0,
                      color: Colors.black87,
                      fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'me@domain.com',
                      hintTextDirection: TextDirection.ltr,
                      hintStyle: const TextStyle(
                          letterSpacing: 1,
                          height: 0.0,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w400,
                          color: messngrGrey),
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

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              child: Column(
                children: [
                  CustomSwitch(
                    activeText: 'Phone',
                    activeTooltip: 'Use phone number to authenticate',
                    inactiveText: 'Email',
                    inactiveTooltip: 'Use email to authenticate',
                    value: useMsisdnForAuth,
                    activeColor: Colors.deepPurple,
                    inactiveColor: Colors.deepPurple,
                    onChanged: (value) {
                      setState(() {
                        useMsisdnForAuth = value;
                      });
                    },
                  ),
                  inputWidget,
                  ElevatedButton(
                    onPressed: () => {
                      if (allowUserToContinue) {sendLoginRequest(context)}
                    },
                    child: const Text('Next'),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget choose(String head, int index) {
    //var prov = Provider.of<AppProvider>(context);
    if (1 == index) {
      return headers(head: head);
    } else {
      return headers(head: head, isSelect: false);
    }
  }
}

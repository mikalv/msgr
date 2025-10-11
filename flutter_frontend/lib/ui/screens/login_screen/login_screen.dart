import 'dart:io';

import 'package:flutter/material.dart';
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/ui/widgets/MobileInputWithOutline.dart';
import 'package:libmsgr/src/registration_service.dart';
import 'dart:developer' as developer;

import 'package:overlay_support/overlay_support.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneNo = TextEditingController();
  String? phoneCode = DEFAULT_COUNTTRYCODE_NUMBER;
  final reg = RegistrationService();
  late String deviceIdStr;
  late String deviceId;
  late String phoneNumber;

  @override
  void initState() {
    super.initState();
    developer.log('Should have started RegistrationService');
    reg.maybeRegisterDevice();
  }

  sendLoginRequest(context) async {
    developer.log('Requesting login for number $phoneNumber');
    var success = await reg.requestForSignInCodeMsisdn(phoneNumber);
    if (success) {
      AppNavigation.router.push(
        AppNavigation.loginCodePath,
      );
    } else {
      // TODO: Handle this error somehow...
      if (Platform.isIOS || Platform.isAndroid) {
        showSimpleNotification(
            const Text(
                'Whops! Something seems wrong in our end. Sorry for this, please try again later!'),
            background: Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              child: Column(
                children: [
                  MobileInputWithOutline(
                    borderColor: messngrGrey.withOpacity(0.2),
                    controller: _phoneNo,
                    initialCountryCode: DEFAULT_COUNTTRYCODE_ISO,
                    width: 300,
                    onSaved: (phone) {
                      var phoneCode = phone!.countryCode;
                      var number = phone.number;
                      developer.log('Mobile: $phoneCode  -  $number');
                      phoneNumber = '$phoneCode$number';
                    },
                  ),
                  ElevatedButton(
                    child: const Text('Next'),
                    onPressed: () => {
                      //showSimpleNotification( const Text("Hei Olav. This is progress :)"), background: Colors.green);
                      /*Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => HomeScreen()),
                      )*/
                      sendLoginRequest(context)
                    },
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/authentication/auth_actions.dart';
import 'package:messngr/utils/flutter_redux.dart';
import 'package:pinput/pinput.dart';
import 'package:smart_auth/smart_auth.dart';
import 'package:libmsgr/src/registration_service.dart';

class PinputLoginCode extends StatefulWidget {
  const PinputLoginCode({super.key});

  @override
  State<PinputLoginCode> createState() => _PinputLoginCodeState();
}

class _PinputLoginCodeState extends State<PinputLoginCode> {
  late final SmsRetriever smsRetriever;
  late final TextEditingController pinController;
  late final FocusNode focusNode;
  late final GlobalKey<FormState> formKey;
  final reg = RegistrationService();

  @override
  void initState() {
    super.initState();
    formKey = GlobalKey<FormState>();
    pinController = TextEditingController();
    focusNode = FocusNode();

    /// In case you need an SMS autofill feature
    if (!kIsWeb) {
      if (Platform.isIOS || Platform.isAndroid) {
        smsRetriever = SmsRetrieverImpl(
          SmartAuth(),
        );
      }
    }
  }

  @override
  void dispose() {
    pinController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  sendCodeToServer(context, pin) async {
    debugPrint('onCompleted: $pin');

    final completer = Completer();
    completer.future.then((val) {
      debugPrint('User: ${val.toString()}');
      //StoreProvider.of<AppState>(context).dispatch(NavigateToNewRouteAction(route: AppNavigation.selectTeamPath));
    }).catchError((error) {
      debugPrint('ERROR: $error');
    });
    final store = StoreProvider.of<AppState>(context);
    if (store.state.authState.pendingMsisdn != null) {
      store.dispatch(LogInMsisdnAction(
          msisdn: store.state.authState.pendingMsisdn!,
          code: pin,
          completer: completer));
    } else {
      store.dispatch(LogInEmailAction(
          email: store.state.authState.pendingEmail!,
          code: pin,
          completer: completer));
    }
  }

  @override
  Widget build(BuildContext context) {
    const focusedBorderColor = Color.fromRGBO(23, 171, 144, 1);
    const fillColor = Color.fromRGBO(243, 246, 249, 0);
    const borderColor = Color.fromRGBO(23, 171, 144, 0.4);

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(
        fontSize: 22,
        color: Color.fromRGBO(30, 60, 87, 1),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: borderColor),
      ),
    );

    /// Optionally you can use form to validate the Pinput
    return Form(
      key: formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Directionality(
            // Specify direction if desired
            textDirection: TextDirection.ltr,
            child: Pinput(
              length: 6,
              showCursor: true,
              autofocus: true,
              // You can pass your own SmsRetriever implementation based on any package
              // in this example we are using the SmartAuth
              smsRetriever: (!kIsWeb && (Platform.isIOS || Platform.isAndroid))
                  ? smsRetriever
                  : null,
              controller: pinController,
              focusNode: focusNode,
              defaultPinTheme: defaultPinTheme,
              separatorBuilder: (index) => const SizedBox(width: 8),
              /*validator: (value) {
                return value == '2222' ? null : 'Pin is incorrect';
              },*/
              hapticFeedbackType: HapticFeedbackType.lightImpact,
              onCompleted: (pin) {
                sendCodeToServer(context, pin);
              },
              onChanged: (value) {
                debugPrint('onChanged: $value');
              },
              cursor: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 9),
                    width: 22,
                    height: 1,
                    color: focusedBorderColor,
                  ),
                ],
              ),
              focusedPinTheme: defaultPinTheme.copyWith(
                decoration: defaultPinTheme.decoration!.copyWith(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: focusedBorderColor),
                ),
              ),
              submittedPinTheme: defaultPinTheme.copyWith(
                decoration: defaultPinTheme.decoration!.copyWith(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: focusedBorderColor),
                ),
              ),
              errorPinTheme: defaultPinTheme.copyBorderWith(
                border: Border.all(color: Colors.redAccent),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              focusNode.unfocus();
              formKey.currentState!.validate();
            },
            child: const Text('Validate'),
          ),
        ],
      ),
    );
  }
}

/// You, as a developer should implement this interface.
/// You can use any package to retrieve the SMS code. in this example we are using SmartAuth
class SmsRetrieverImpl implements SmsRetriever {
  const SmsRetrieverImpl(this.smartAuth);

  final SmartAuth smartAuth;

  @override
  Future<void> dispose() {
    return smartAuth.removeSmsListener();
  }

  @override
  Future<String?> getSmsCode() async {
    final signature = await smartAuth.getAppSignature();
    debugPrint('App Signature: $signature');
    final res = await smartAuth.getSmsCode(
      useUserConsentApi: true,
    );
    if (res.succeed && res.codeFound) {
      return res.code!;
    }
    return null;
  }

  @override
  bool get listenForMultipleSms => false;
}

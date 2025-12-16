import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messngr/providers/auth_provider.dart';
import 'package:pinput/pinput.dart';
import 'package:smart_auth/smart_auth.dart';
import 'package:libmsgr/src/registration_service.dart';

class PinputLoginCode extends ConsumerStatefulWidget {
  const PinputLoginCode({super.key});

  @override
  ConsumerState<PinputLoginCode> createState() => _PinputLoginCodeState();
}

class _PinputLoginCodeState extends ConsumerState<PinputLoginCode> {
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

    try {
      final authState = ref.read(authProvider);
      final challengeId = authState.pendingChallengeId;
      final displayName = authState.pendingDisplayName;

      if (challengeId == null) {
        debugPrint('ERROR: No pending challenge ID');
        return;
      }

      if (authState.pendingMsisdn != null) {
        // Phone login
        final user = await reg.submitMsisdnCodeForToken(
          challengeId: challengeId,
          code: pin,
          displayName: displayName,
        );
        if (user != null) {
          ref.read(authProvider.notifier).setCurrentUser(user);
          debugPrint('User logged in: ${user.toString()}');
        }
      } else if (authState.pendingEmail != null) {
        // Email login
        final user = await reg.submitEmailCodeForToken(
          challengeId: challengeId,
          code: pin,
          displayName: displayName,
        );
        if (user != null) {
          ref.read(authProvider.notifier).setCurrentUser(user);
          debugPrint('User logged in: ${user.toString()}');
        }
      }
    } catch (error) {
      debugPrint('ERROR: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final targetHint = authState.pendingTargetHint ??
        authState.pendingEmail ??
        authState.pendingMsisdn;
    final debugCode = authState.pendingDebugCode;

    const focusedBorderColor = Color(0xFF6366F1);
    final fillColor = Colors.white.withOpacity(0.06);
    final borderColor = Colors.white.withOpacity(0.28);

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(
        fontSize: 22,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
    );

    /// Optionally you can use form to validate the Pinput
    return Form(
      key: formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (targetHint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  const Text(
                    'Skriv inn engangskoden vi nettopp sendte deg',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    targetHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (debugCode != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Kode (kun utvikling): $debugCode',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.amberAccent,
                        ),
                      ),
                    )
                ],
              ),
            ),
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
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: focusedBorderColor),
                ),
              ),
              errorPinTheme: defaultPinTheme.copyBorderWith(
                border: Border.all(color: Colors.redAccent),
              ),
            ),
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

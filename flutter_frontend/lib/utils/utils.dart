import 'dart:io';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:messngr/config/app_constants.dart';

class Messngr {
  static void toast(String message) {
    Fluttertoast.showToast(
        msg: message,
        backgroundColor: messngrBlack.withOpacity(0.95),
        textColor: messngrWhite);
  }

  static void internetLookUp() async {
    try {
      await InternetAddress.lookup('google.com').catchError((e) {
        Messngr.toast('No internet connection ${e.toString()}');
      });
    } catch (err) {
      Messngr.toast('No internet connection. ${err.toString()}');
    }
  }

  static String normalizePhone(String phone) =>
      phone.replaceAll(RegExp(r'\s+\b|\b\s'), '');
}

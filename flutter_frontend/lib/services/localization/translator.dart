import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String LAGUAGE_CODE = 'languageCode';

//languages code
const String ENGLISH = 'en';
List languagelist = [
  ENGLISH,
];
List<Locale> supportedlocale = [
  const Locale(ENGLISH, 'US'),
];

Future<Locale> setLocale(String languageCode) async {
  print(languageCode);
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString(LAGUAGE_CODE, languageCode);
  return _locale(languageCode);
}

Future<Locale> getLocale() async {
  print(LAGUAGE_CODE);
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String languageCode = prefs.getString(LAGUAGE_CODE) ?? 'en';
  return _locale(languageCode);
}

Locale _locale(String languageCode) {
  switch (languageCode) {
    case ENGLISH:
      return const Locale(ENGLISH, 'US');

    default:
      return const Locale(ENGLISH, 'US');
  }
}

String getTranslated(BuildContext context, String key) {
  return key; //DemoLocalization.of(context)!.translate(key) ?? '';
}

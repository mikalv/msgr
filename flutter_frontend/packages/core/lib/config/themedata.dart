import 'package:flutter/material.dart';
import 'package:messngr/config/app_constants.dart';

final borderColor = messngrGrey.withOpacity(0.2);
final borderStyle = OutlineInputBorder(
  borderRadius: const BorderRadius.all(
    Radius.circular(10.0),
  ),
  borderSide: BorderSide(color: borderColor, width: 0.0),
);

const formTextStyle = TextStyle(
    height: 1.35,
    letterSpacing: 1,
    fontSize: 16.0,
    color: Colors.black87,
    fontWeight: FontWeight.bold);

const formHintTextStyle = TextStyle(
    letterSpacing: 1,
    height: 0.0,
    fontSize: 15.5,
    fontWeight: FontWeight.w400,
    color: messngrGrey);

const errorTextStyle = TextStyle(
    height: 1.55,
    letterSpacing: 1,
    fontSize: 18.0,
    color: Colors.red,
    fontWeight: FontWeight.bold);

final materialThemeData = ThemeData(
  // This is the theme of your application.
  //
  // TRY THIS: Try running your application with "flutter run". You'll see
  // the application has a purple toolbar. Then, without quitting the app,
  // try changing the seedColor in the colorScheme below to Colors.green
  // and then invoke "hot reload" (save your changes or press the "hot
  // reload" button in a Flutter-supported IDE, or press "r" if you used
  // the command line to start the app).
  //
  // Notice that the counter didn't reset back to zero; the application
  // state is not lost during the reload. To reset the state, use hot
  // restart instead.
  //
  // This works for code too, not just values: Most code changes can be
  // tested with just a hot reload.
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
  hintColor: const Color.fromARGB(255, 160, 29, 211),
  useMaterial3: true,
);

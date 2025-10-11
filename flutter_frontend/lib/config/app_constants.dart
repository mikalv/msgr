//*--App Configurations---

import 'package:flutter/material.dart';

const String appName =
    'Messngr'; //app name shown evrywhere with the app where required
const String DEFAULT_COUNTTRYCODE_ISO =
    'NO'; //default country ISO 2 letter for login screen
const String DEFAULT_COUNTTRYCODE_NUMBER =
    '+47'; //default country code number for login screen

// MSISDN

const hmm = '🤔';

const appTitle = 'Messngr';

const isDarkMode = true;

const minimumSecondsBetweenFlushStateToDisk = 5;
const appStatePersistFile = 'state.json';
const kReduxPersistorInDebugMode = false;
const kReduxUseWebTools = false;
const kGoRouterDiagnostic = true;
const kSendFocusAndBlurEvents = false;

const String emojiRegExpression =
    r'(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])';
const String imageUrlRegExpression =
    r'(http(s?):)([/|.|\w|\s|-])*\.(?:jpg|gif|png|jpeg)';

// TODO: Should be dynamically read?
const assumedMacOSTitleBarHeight = 24;

const defaultDesktopWindowSize = Size(800, 700);
const minimumDesktopWindowSize = Size(800, 700);
const maxWidthBeforeSidebarNavigation = 550;

const messngrBlack = Color(0xFF1E1E1E);
const messngrBlue = Color(0xFF02ac88);
const messngrDeepGreen = Color(0xFF01826b);
const messngrLightGreen = Color(0xFF02ac88);
const messngrgreen = Color(0xFF01826b);
const messngrteagreen = Color(0xFFe9fedf);
const messngrWhite = Colors.white;
const messngrGrey = Color(0xff85959f);
const messngrChatbackground = Color(0xffe8ded5);

const kSupportedLocales = <Locale>[
  Locale('en', 'US'),
  Locale('no', 'NO'),
];

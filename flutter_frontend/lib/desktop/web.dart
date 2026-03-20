import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/config/theme.dart';
import 'package:messngr/config/themedata.dart';
import 'package:messngr/services/app_localizations.dart';
import 'package:messngr/services/localization/translator.dart';

class WebApp extends StatefulWidget {
  const WebApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    _WebAppState state = context.findAncestorStateOfType<_WebAppState>()!;
    state.setLocale(newLocale);
  }

  @override
  State<WebApp> createState() => _WebAppState();
}

class _WebAppState extends State<WebApp>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  Locale? _locale;
  bool hasFocus = true;
  Brightness? _brightness;

  _WebAppState();

  setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  void didChangeDependencies() {
    getLocale().then((locale) {
      setState(() {
        _locale = locale;
      });
    });
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
    getLocale().then((locale) {
      setState(() {
        _locale = locale;
      });
    });
  }

  Widget loadingScreen() {
    var progCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addListener(() {
        setState(() {});
      });
    final appThemeData = AppThemeData(brightness: _brightness);
    return AppTheme(
      data: appThemeData,
      child: CupertinoApp(
        title: appTitle,
        theme: appThemeData.getCupertinoThemeData(_brightness),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        supportedLocales: kSupportedLocales,
        localeResolutionCallback: (locale, supportedLocales) {
          for (var supportedLocale in supportedLocales) {
            if (supportedLocale.languageCode == locale!.languageCode &&
                supportedLocale.countryCode == locale.countryCode) {
              return supportedLocale;
            }
          }
          return null;
        },
        home: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            const Directionality(
                textDirection: TextDirection.ltr,
                child: Text('Please wait while loading all modules..')),
            CircularProgressIndicator(
              value: progCtrl.value,
              semanticsLabel: 'Circular progress indicator',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appThemeData = AppThemeData(brightness: _brightness);
    return ProviderScope(
      child: AppTheme(
        data: appThemeData,
        child: CupertinoApp.router(
          title: appTitle,
          debugShowCheckedModeBanner: false,
          theme: appThemeData.getCupertinoThemeData(_brightness),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
            DefaultCupertinoLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          supportedLocales: kSupportedLocales,
          localeResolutionCallback: (locale, supportedLocales) {
            for (var supportedLocale in supportedLocales) {
              if (supportedLocale.languageCode == locale!.languageCode &&
                  supportedLocale.countryCode == locale.countryCode) {
                return supportedLocale;
              }
            }
            return null;
          },
          routerConfig: AppNavigation.router,
        ),
      ),
    );
  }
}

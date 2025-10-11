import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/config/theme.dart';
import 'package:messngr/config/themedata.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/authentication/auth_actions.dart';
import 'package:messngr/redux/setup.dart';
import 'package:messngr/services/app_localizations.dart';
import 'package:messngr/services/localization/translator.dart';
import 'package:messngr/ui/widgets/desktop/TitlebarSafeArea.dart';
import 'package:messngr/utils/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:window_manager/window_manager.dart';

class WindowsApp extends StatefulWidget {
  const WindowsApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    _WindowsAppState state =
        context.findAncestorStateOfType<_WindowsAppState>()!;
    state.setLocale(newLocale);
  }

  @override
  State<WindowsApp> createState() => _WindowsAppState();
}

class _WindowsAppState extends State<WindowsApp>
    with WidgetsBindingObserver, TickerProviderStateMixin, WindowListener {
  Locale? _locale;
  bool hasFocus = true;
  Brightness? _brightness;
  final Future<Store<AppState>> reduxStore = ReduxSetup.getReduxStore();

  _WindowsAppState();

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
    WidgetsBinding.instance.addObserver(this);
    _brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    windowManager.addListener(this);
    windowManager.setPreventClose(true);
    super.initState();
    reduxStore.then((store) {
      store.dispatch(VerifyAuthStateAction());
      store.dispatch(OpenWebsocketIfNotAlready());
    });
    getLocale().then((locale) {
      setState(() {
        _locale = locale;
      });
    });
  }

  Widget loadingScreen() {
    var progCtrl = AnimationController(
      /// [AnimationController]s can be created with `vsync: this` because of
      /// [TickerProviderStateMixin].
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addListener(() {
        setState(() {});
      });
    //progCtrl.repeat(reverse: true);
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
    return TitlebarSafeArea(
      child: FutureBuilder(
        future: reduxStore,
        builder:
            (BuildContext context, AsyncSnapshot<Store<AppState>> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return loadingScreen();
            default:
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              } else {
                final appThemeData = AppThemeData(brightness: _brightness);
                return StoreProvider(
                    store: snapshot.data!,
                    child: AppTheme(
                      data: appThemeData,
                      child: CupertinoApp.router(
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
                            if (supportedLocale.languageCode ==
                                    locale!.languageCode &&
                                supportedLocale.countryCode ==
                                    locale.countryCode) {
                              return supportedLocale;
                            }
                          }
                          return null;
                        },
                        routerConfig: AppNavigation.router,
                      ),
                    ));
              }
          }
        },
      ),
    );
  }
}

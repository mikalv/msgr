import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/config/theme.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/authentication/auth_actions.dart';
import 'package:messngr/redux/setup.dart';
import 'package:messngr/redux/ui/ui_actions.dart';
import 'package:messngr/services/app_localizations.dart';
import 'package:messngr/services/localization/translator.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/ui/screens/error_screen/error_screen.dart';
import 'package:messngr/ui/widgets/desktop/TitlebarSafeArea.dart';
import 'package:messngr/utils/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:window_manager/window_manager.dart';

class MacOSApp extends StatefulWidget {
  const MacOSApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    _MacOSAppState state = context.findAncestorStateOfType<_MacOSAppState>()!;
    state.setLocale(newLocale);
  }

  @override
  State<MacOSApp> createState() => _MacOSAppState();
}

class _MacOSAppState extends State<MacOSApp>
    with WidgetsBindingObserver, TickerProviderStateMixin, WindowListener {
  Locale? _locale;
  bool hasFocus = true;
  Brightness? _brightness;
  final Future<Store<AppState>> reduxStore = ReduxSetup.getReduxStore();

  _MacOSAppState();

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
  initState() {
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowEvent(String eventName) {
    if (eventName == 'resized') {
      reduxStore.then((store) async => {
            store.dispatch(
                OnWindowResize(windowSize: await windowManager.getSize()))
          });
    } else if (eventName == 'moved') {
      reduxStore.then((store) async => {
            store.dispatch(
                OnWindowMove(windowPosition: await windowManager.getPosition()))
          });
    } else if (eventName == 'blur') {
      if (kSendFocusAndBlurEvents) {
        reduxStore.then((store) => {store.dispatch(OnWindowBlur())});
      }
    } else if (eventName == 'focus') {
      if (kSendFocusAndBlurEvents) {
        reduxStore.then((store) => {store.dispatch(OnWindowFocus())});
      }
    } else if (eventName == 'minimize') {
      reduxStore.then((store) => {store.dispatch(OnWindowMinimize())});
    } else if (eventName == 'restore') {
      reduxStore.then((store) => {store.dispatch(OnWindowRestore())});
    }
    print('[WindowManager] onWindowEvent: $eventName');
  }

  @override
  void onWindowFocus() {
    // Make sure to call once.
    setState(() {
      hasFocus = true;
    });
    // do something
  }

  @override
  void onWindowBlur() {
    // Make sure to call once.
    setState(() {
      hasFocus = false;
    });
    // do something
  }

  @override
  void didChangePlatformBrightness() {
    if (mounted) {
      setState(() {
        _brightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
      });
    }

    super.didChangePlatformBrightness();
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
                return Directionality(
                    textDirection: TextDirection.ltr,
                    child: ErrorScreen(error: snapshot.error));
              } else {
                final appThemeData = AppThemeData(brightness: _brightness);
                return StoreProvider(
                    store: snapshot.data!,
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

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('Are you sure you want to close this window?'),
            actions: [
              TextButton(
                child: const Text('No'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('Yes'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await windowManager.destroy();
                },
              ),
            ],
          );
        },
      );
    }
  }
}

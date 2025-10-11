import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/config/theme.dart';
import 'package:messngr/config/themedata.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/authentication/auth_actions.dart';
import 'package:messngr/redux/setup.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/services/app_localizations.dart';
import 'package:messngr/utils/flutter_redux.dart';
import 'package:messngr/services/localization/translator.dart';
import 'package:redux/redux.dart';

class MessngrApp extends StatelessWidget {
  const MessngrApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MessngrWrapper();
  }
}

class MessngrWrapper extends StatefulWidget {
  const MessngrWrapper({super.key});
  static void setLocale(BuildContext context, Locale newLocale) {
    _MessngrWrapperState state =
        context.findAncestorStateOfType<_MessngrWrapperState>()!;
    state.setLocale(newLocale);
  }

  @override
  _MessngrWrapperState createState() => _MessngrWrapperState();
}

class _MessngrWrapperState extends State<MessngrWrapper>
    with TickerProviderStateMixin {
  Locale? _locale;
  final Future<Store<AppState>> reduxStore = ReduxSetup.getReduxStore();

  _MessngrWrapperState();

  setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  void initState() {
    super.initState();
    reduxStore.then((store) {
      store.dispatch(OpenWebsocketIfNotAlready());
    });
    getLocale().then((locale) {
      setState(() {
        _locale = locale;
      });
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

  Widget loadingScreen() {
    var progCtrl = AnimationController(
      /// [AnimationController]s can be created with `vsync: this` because of
      /// [TickerProviderStateMixin].
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addListener(() {
        setState(() {});
      });
    return MaterialApp(
      title: appTitle,
      theme: materialThemeData,
      debugShowCheckedModeBanner: false,
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
          const Text('Please wait while loading all modules..'),
          CircularProgressIndicator(
            value: progCtrl.value,
            semanticsLabel: 'Loading modules',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
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
                final appThemeData = AppThemeData();
                return StoreProvider(
                    store: snapshot.data!,
                    child: AppTheme(
                        data: appThemeData,
                        child: MaterialApp.router(
                          title: appTitle,
                          theme: materialThemeData,
                          debugShowCheckedModeBanner: false,
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
                          },
                          routerConfig: AppNavigation.router,
                        )));
              }
          }
        });
  }
}

class CustomError extends StatelessWidget {
  final FlutterErrorDetails errorDetails;

  const CustomError({
    super.key,
    required this.errorDetails,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 0,
      width: 0,
    );
  }
}

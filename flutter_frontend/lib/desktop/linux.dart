import 'package:flutter/material.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/authentication/auth_actions.dart';
import 'package:messngr/redux/setup.dart';
import 'package:messngr/services/localization/translator.dart';
import 'package:redux/redux.dart';

class LinuxApp extends StatefulWidget {
  const LinuxApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    _LinuxAppState state = context.findAncestorStateOfType<_LinuxAppState>()!;
    state.setLocale(newLocale);
  }

  @override
  State<LinuxApp> createState() => _LinuxAppState();
}

class _LinuxAppState extends State<LinuxApp> {
  Locale? _locale;
  final Future<Store<AppState>> reduxStore = ReduxSetup.getReduxStore();

  _LinuxAppState();

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }
}

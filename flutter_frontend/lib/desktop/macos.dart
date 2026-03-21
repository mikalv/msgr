import 'dart:io' show exit;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/config/theme.dart';
import 'package:messngr/services/app_localizations.dart';
import 'package:messngr/services/localization/translator.dart';
import 'package:window_manager/window_manager.dart';
import 'package:messngr/main_desktop.dart' show saveWindowBounds;
import 'package:core/providers/auth_state_provider.dart';
import 'package:core/providers/unread_provider.dart';
import 'package:core/ui/auth/simple_login_screen.dart';
import 'package:core/ui/shell/app_shell.dart';
import 'package:core/ui/shell/simple_chat_content.dart';

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
  void onWindowEvent(String eventName) {}

  @override
  void onWindowMoved() => saveWindowBounds();

  @override
  void onWindowResized() => saveWindowBounds();

  @override
  void onWindowFocus() {
    setState(() {
      hasFocus = true;
    });
  }

  @override
  void onWindowBlur() {
    setState(() {
      hasFocus = false;
    });
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
    return ProviderScope(
      child: PlatformMenuBar(
        menus: [
          PlatformMenu(
            label: 'Messngr',
            menus: [
              PlatformMenuItem(
                label: 'Om Messngr',
                onSelected: () {
                  // Show about dialog
                  showAboutDialog(
                    context: context,
                    applicationName: 'Messngr',
                    applicationVersion: '0.1.1',
                  );
                },
              ),
              PlatformMenuItemGroup(
                members: [
                  PlatformMenuItem(
                    label: 'Innstillinger...',
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.comma,
                      meta: true,
                    ),
                    onSelected: () {
                      // TODO: Open settings
                    },
                  ),
                ],
              ),
              PlatformMenuItemGroup(
                members: [
                  PlatformMenuItem(
                    label: 'Avslutt Messngr',
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyQ,
                      meta: true,
                    ),
                    onSelected: () => exit(0),
                  ),
                ],
              ),
            ],
          ),
          PlatformMenu(
            label: 'Rediger',
            menus: [
              PlatformMenuItem(
                label: 'Angre',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyZ,
                  meta: true,
                ),
                onSelected: null,
              ),
              PlatformMenuItem(
                label: 'Gjenta',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyZ,
                  meta: true,
                  shift: true,
                ),
                onSelected: null,
              ),
              PlatformMenuItemGroup(
                members: [
                  PlatformMenuItem(
                    label: 'Klipp ut',
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyX,
                      meta: true,
                    ),
                    onSelected: null,
                  ),
                  PlatformMenuItem(
                    label: 'Kopier',
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyC,
                      meta: true,
                    ),
                    onSelected: null,
                  ),
                  PlatformMenuItem(
                    label: 'Lim inn',
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyV,
                      meta: true,
                    ),
                    onSelected: null,
                  ),
                  PlatformMenuItem(
                    label: 'Merk alt',
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyA,
                      meta: true,
                    ),
                    onSelected: null,
                  ),
                ],
              ),
            ],
          ),
          PlatformMenu(
            label: 'Vis',
            menus: [
              PlatformMenuItem(
                label: 'Hurtigveksler',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyK,
                  meta: true,
                ),
                onSelected: null, // Handled by CallbackShortcuts in AppShell
              ),
            ],
          ),
          PlatformMenu(
            label: 'Vindu',
            menus: [
              PlatformMenuItem(
                label: 'Minimer',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyM,
                  meta: true,
                ),
                onSelected: () => windowManager.minimize(),
              ),
              PlatformMenuItem(
                label: 'Zoom',
                onSelected: () async {
                  if (await windowManager.isMaximized()) {
                    windowManager.unmaximize();
                  } else {
                    windowManager.maximize();
                  }
                },
              ),
            ],
          ),
        ],
        child: MaterialApp(
            title: appTitle,
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorSchemeSeed: const Color(0xFF02AC88),
              brightness: _brightness ?? Brightness.light,
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorSchemeSeed: const Color(0xFF02AC88),
              brightness: Brightness.dark,
              useMaterial3: true,
            ),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              DefaultMaterialLocalizations.delegate,
              DefaultCupertinoLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            supportedLocales: kSupportedLocales,
            home: const _AuthGate(),
        ),
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

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(simpleAuthProvider);

    // Update dock badge with total unread count
    if (auth.isLoggedIn) {
      final totalUnread = ref.watch(totalUnreadProvider);
      // window_manager supports setBadgeLabel on macOS
      if (totalUnread > 0) {
        windowManager.setBadgeLabel('$totalUnread');
      } else {
        windowManager.setBadgeLabel('');
      }
      return const AppShell(child: SimpleChatContent());
    }

    // Clear badge when logged out
    windowManager.setBadgeLabel('');
    return const SimpleLoginScreen();
  }
}

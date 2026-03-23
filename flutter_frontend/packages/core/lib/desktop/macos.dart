import 'dart:io' show exit;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/config/app_constants.dart';
import 'package:core/config/theme.dart';
import 'package:core/providers/auth_state_provider.dart';
import 'package:core/providers/push_provider.dart';
import 'package:core/providers/unread_provider.dart';
import 'package:core/services/app_localizations.dart';
import 'package:core/services/desktop_notification_service.dart';
import 'package:core/services/localization/translator.dart';
import 'package:core/ui/auth/simple_login_screen.dart';
import 'package:core/ui/settings/settings_page.dart';
import 'package:core/ui/shell/app_shell.dart';
import 'package:core/ui/shell/chat/simple_chat_content.dart';
import 'package:core/ui/widgets/desktop/TitlebarSafeArea.dart';
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
  final _navigatorKey = GlobalKey<NavigatorState>();

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
  void onWindowEvent(String eventName) {
    print('[WindowManager] onWindowEvent: $eventName');
  }

  @override
  void onWindowFocus() {
    setState(() {
      hasFocus = true;
    });
    DesktopNotificationService.isWindowFocused = true;
  }

  @override
  void onWindowBlur() {
    setState(() {
      hasFocus = false;
    });
    DesktopNotificationService.isWindowFocused = false;
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
    final appThemeData = AppThemeData(brightness: _brightness);
    return ProviderScope(
      child: PlatformMenuBar(
        menus: [
          PlatformMenu(
            label: 'Messngr',
            menus: [
              PlatformMenuItem(
                label: 'Om Messngr',
                onSelected: () {
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
                    label: 'Settings...',
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.comma,
                      meta: true,
                    ),
                    onSelected: () {
                      final ctx = _navigatorKey.currentContext;
                      if (ctx != null) {
                        openSettingsPage(ctx);
                      }
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
                onSelected: null,
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
        child: TitlebarSafeArea(
          child: AppTheme(
            data: appThemeData,
            child: MaterialApp(
              navigatorKey: _navigatorKey,
              title: appTitle,
              debugShowCheckedModeBanner: false,
              theme: ThemeData.dark().copyWith(
                colorScheme: ColorScheme.dark(
                  primary: const Color(0xFF02ac88),
                  secondary: const Color(0xFF02ac88),
                ),
                scaffoldBackgroundColor: const Color(0xFF1E1E1E),
              ),
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
              home: const _AuthGate(),
            ),
          ),
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

/// Gates the app on simple auth state.
/// Shows login screen if not authenticated, app shell + chat if authenticated.
/// Shows a loading spinner while checking saved session on startup.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(simpleAuthProvider);

    // Show loading spinner while checking saved session
    if (authState.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1E1E1E),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!authState.isLoggedIn) {
      windowManager.setBadgeLabel('');
      return const SimpleLoginScreen();
    }

    // Update dock badge with total unread count
    final totalUnread = ref.watch(totalUnreadProvider);
    if (totalUnread > 0) {
      windowManager.setBadgeLabel('$totalUnread');
    } else {
      windowManager.setBadgeLabel('');
    }

    // Initialize push notification manager (auto-registers token when logged in)
    print('[DEBUG] About to watch pushManagerProvider');
    final pushManager = ref.watch(pushManagerProvider);
    print('[DEBUG] pushManager obtained, calling init');
    Future.microtask(() => pushManager.init());

    return const AppShell(child: SimpleChatContent());
  }
}

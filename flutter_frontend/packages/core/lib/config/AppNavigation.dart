// ignore_for_file: slash_for_doc_comments

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/services/navigator_observer.dart';
import 'package:messngr/ui/pages/conversation_page/create_conversation_page.dart';
import 'package:messngr/ui/pages/home_page/home_page.dart';
import 'package:messngr/ui/pages/invite_page/invite_page.dart';
import 'package:messngr/ui/pages/room_page/create_room_page.dart';
import 'package:messngr/ui/pages/room_page/room_page.dart';
import 'package:messngr/ui/pages/settings_page/settings_page.dart';
import 'package:messngr/ui/screens/create_profile_screen.dart';
import 'package:messngr/ui/screens/main_screen/main_screen.dart';
import 'package:messngr/ui/screens/login_screen/code_screen.dart';
import 'package:messngr/ui/screens/login_screen/login_screen.dart';
import 'package:messngr/ui/screens/register_screen/register_code_screen.dart';
import 'package:messngr/ui/screens/register_screen/register_new_team_screen.dart';
import 'package:messngr/ui/screens/select_current_team_screen.dart';
import 'package:messngr/ui/screens/register_screen/register_user_screen.dart';
import 'package:messngr/ui/screens/welcome_screen/welcome_screen.dart';
import 'package:messngr/utils/flutter_redux.dart';

///
/// AppNavigation
///
/// - A core part of the application.
///
/// Can be hard to understand, reading this might help:
/// https://medium.com/flutter-community/integrating-bottom-navigation-with-go-router-in-flutter-c4ec388da16a
/// https://pub.dev/documentation/go_router/latest/topics/Get%20started-topic.html
///
///
/// Example of how to use for navigating to a different page/screen/view:
///
/// AppNavigation.router.push(
///     AppNavigation.loginCodePath,
/// );
///
///
/// This link might be helpful;
/// https://oziemski.medium.com/flutter-navigation-with-redux-8433af750eb1
///
///

/**
 * What do you want?
 *
 * You actually either:

Don't want to display that ugly back button ( :] ), and thus go for : 
AppBar(...,automaticallyImplyLeading: false,...);

Don't want the user to go back - replacing current view - and thus go for: 
Navigator.pushReplacementNamed(## your routename here ##);

Don't want the user to go back - replacing a certain view back in the stack - and thus use: 
Navigator.pushNamedAndRemoveUntil(## your routename here ##, f(Route<dynamic>)→bool); 
where f is a function returning truewhen meeting the last view you want to keep in the stack 
(right before the new one);

Don't want the user to go back - EVER - emptying completely the navigator stack with: 
Navigator.pushNamedAndRemoveUntil(context, ## your routename here ##, (_) => false);
 */
class AppNavigation {
  final Logger _log = Logger('AppNavigation');
  static final AppNavigation _instance = AppNavigation._internal();

  static AppNavigation get instance => _instance;

  static late final GoRouter router;

  static GlobalKey<NavigatorState> parentNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');
  static GlobalKey<NavigatorState> homeTabNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'homeTab');
  static GlobalKey<NavigatorState> messagesTabNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'messagesTab');
  static GlobalKey<NavigatorState> discoverTabNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'discoverTab');
  static GlobalKey<NavigatorState> searchTabNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'searchTab');
  static GlobalKey<NavigatorState> settingsTabNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'settingsTab');

  BuildContext get context =>
      router.routerDelegate.navigatorKey.currentContext!;

  GoRouterDelegate get routerDelegate => router.routerDelegate;

  GoRouteInformationParser get routeInformationParser =>
      router.routeInformationParser;

  static const String loginPath = '/login';
  static const String loginCodePath = '/login/code';
  static const String registerPath = '/register/user';
  static const String registerCodePath = '/register/code';
  static const String registerTeamPath = '/register/team';
  static const String selectTeamPath = '/select/team';
  static const String createProfilePath = '/create/profile';
  static const String inviteMemberPath = '/invite/member';

  static const String detailPath = '/detail';
  static const String rootDetailPath = '/rootDetail';

  static const String welcomePath = '/';
  static const String homePath = '/home';
  static const String mainPath = '/dashboard';
  static const String dashboardPath = '/dashboard';
  static const String conversationsPath = '/conversations';
  static const String createConversationPath = '/new/conversations/';
  static const String createConversationPathParam =
      '/new/conversations/:teamName';
  static const String channelsPath = '/channels';
  static const String roomsPath = '/rooms';
  static const String createRoomPath = '/new/rooms/';
  static const String createRoomPathParam = '/new/rooms/:teamName';
  static const String discoveryPath = '/discovery';
  static const String settingsPath = '/settings';
  static const String searchPath = '/search';

  static const navBarItems = [
    {'icon': Icon(Icons.home_rounded), 'label': 'Home'},
    {'icon': Icon(Icons.messenger_outline_rounded), 'label': 'DMs'},
    {'icon': Icon(Icons.alternate_email), 'label': 'Mentions'},
    {'icon': Icon(Icons.search_rounded), 'label': 'Search'},
    {'icon': Icon(Icons.account_circle), 'label': 'Profile'},
  ];

  factory AppNavigation() {
    return _instance;
  }

  String? redirectWhenNotLoggedIn(BuildContext context, GoRouterState state) {
    if (StoreProvider.of<AppState>(context).state.authState.currentUser ==
        null) {
      _log.info(
          'Redirecting user cause redirectWhenNotLoggedIn (from route ${state.path} to route $welcomePath)');
      return welcomePath;
    }
    return null;
  }

  String? redirectWhenLoggedIn(BuildContext context, GoRouterState state) {
    if (StoreProvider.of<AppState>(context).state.authState.currentUser !=
        null) {
      _log.info(
          'Redirecting user cause redirectWhenLoggedIn (from route ${state.path} to route $dashboardPath)');
      return dashboardPath;
    }
    return null;
  }

  AppNavigation._internal() {
    _log.info('AppNavigation starting up');

    var routesForTab1 = StatefulShellBranch(
      navigatorKey: homeTabNavigatorKey,
      routes: [
        GoRoute(
            path: dashboardPath,
            parentNavigatorKey: homeTabNavigatorKey,
            pageBuilder: (context, GoRouterState state) {
              _log.finer('GoRouter changed to dashboardPath');
              return getPage(
                child: const HomePage(),
                state: state,
              );
            },
            redirect: (BuildContext context, GoRouterState state) {
              return redirectWhenNotLoggedIn(context, state);
            }),
        GoRoute(
            path: createConversationPathParam,
            parentNavigatorKey: homeTabNavigatorKey,
            pageBuilder: (context, GoRouterState state) {
              _log.finer('GoRouter changed to createConversationPath');
              return getPage(
                child: CreateConversationPage(
                    key: const Key('createConversationPage'),
                    teamName: state.pathParameters['teamName'] ?? ''),
                state: state,
              );
            },
            redirect: (BuildContext context, GoRouterState state) {
              return redirectWhenNotLoggedIn(context, state);
            }),
        GoRoute(
            path: createRoomPathParam,
            parentNavigatorKey: homeTabNavigatorKey,
            pageBuilder: (context, GoRouterState state) {
              _log.finer('GoRouter changed to createRoomPath');
              return getPage(
                child: CreateRoomPage(
                    key: const Key('createRoomPage'),
                    teamName: state.pathParameters['teamName'] ?? ''),
                state: state,
              );
            },
            redirect: (BuildContext context, GoRouterState state) {
              return redirectWhenNotLoggedIn(context, state);
            }),
        GoRoute(
            path: inviteMemberPath,
            parentNavigatorKey: homeTabNavigatorKey,
            pageBuilder: (context, GoRouterState state) {
              _log.finer('GoRouter changed to inviteMemberPath');
              return getPage(
                child: const InvitePage(),
                state: state,
              );
            },
            redirect: (BuildContext context, GoRouterState state) {
              return redirectWhenNotLoggedIn(context, state);
            }),
      ],
    );

    var routesForTab2 = StatefulShellBranch(
      navigatorKey: searchTabNavigatorKey,
      routes: [
        GoRoute(
            path: searchPath,
            parentNavigatorKey: searchTabNavigatorKey,
            pageBuilder: (context, state) {
              _log.finer('GoRouter changed to searchPath');
              return getPage(
                child: const HomePage(),
                state: state,
              );
            },
            redirect: (BuildContext context, GoRouterState state) {
              return redirectWhenNotLoggedIn(context, state);
            }),
        GoRoute(
            path: '$roomsPath/:roomID',
            parentNavigatorKey: searchTabNavigatorKey,
            pageBuilder: (context, state) {
              _log.finer('GoRouter changed to roomsPath');
              // state.uri.queryParameters['teamName']!,
              var roomID = state.pathParameters['roomID'];
              return getPage(
                child: RoomPage(
                  roomID: roomID!,
                  teamName: state.uri.queryParameters['teamName'] ?? '',
                ),
                state: state,
              );
            },
            redirect: (BuildContext context, GoRouterState state) {
              return redirectWhenNotLoggedIn(context, state);
            }),
      ],
    );

    var routesForTab3 = StatefulShellBranch(
      navigatorKey: messagesTabNavigatorKey,
      routes: [
        GoRoute(
            path: conversationsPath,
            pageBuilder: (context, state) {
              _log.finer('GoRouter changed to conversationsPath');
              return getPage(
                child: const SettingsPage(),
                state: state,
              );
            },
            redirect: (BuildContext context, GoRouterState state) {
              return redirectWhenNotLoggedIn(context, state);
            }),
      ],
    );

    var routesForTab4 = StatefulShellBranch(
      navigatorKey: discoverTabNavigatorKey,
      routes: [
        GoRoute(
            path: discoveryPath,
            pageBuilder: (context, state) {
              _log.finer('GoRouter changed to discoveryPath');
              return getPage(
                child: const SettingsPage(),
                state: state,
              );
            },
            redirect: (BuildContext context, GoRouterState state) {
              return redirectWhenNotLoggedIn(context, state);
            }),
      ],
    );

    var routesForTab5 = StatefulShellBranch(
      navigatorKey: settingsTabNavigatorKey,
      routes: [
        GoRoute(
            path: settingsPath,
            pageBuilder: (context, state) {
              _log.finer('GoRouter changed to settingsPath');
              return getPage(
                child: const SettingsPage(),
                state: state,
              );
            },
            redirect: (BuildContext context, GoRouterState state) {
              return redirectWhenNotLoggedIn(context, state);
            }),
      ],
    );

    final routes = [
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: parentNavigatorKey,
        branches: [
          routesForTab1,
          routesForTab2,
          routesForTab3,
          routesForTab4,
          routesForTab5
        ],
        pageBuilder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) {
          _log.finer('GoRouter StatefulShellRoute updating');
          return getPage(
            child: MainScreen(
              child: navigationShell,
            ),
            state: state,
          );
        },
      ),
      // Other types of routes, which not include the BottomNavigationBar
      GoRoute(
        parentNavigatorKey: parentNavigatorKey,
        path: loginPath,
        pageBuilder: (context, state) {
          _log.finer('GoRouter changed to loginPath');
          return getPage(
            child: const LoginScreen(),
            state: state,
          );
        },
        redirect: (BuildContext context, GoRouterState state) {
          return redirectWhenLoggedIn(context, state);
        },
      ),
      GoRoute(
        parentNavigatorKey: parentNavigatorKey,
        path: loginCodePath,
        pageBuilder: (context, state) {
          _log.finer('GoRouter changed to loginCodePath');
          return getPage(
            child: const CodeScreen(),
            state: state,
          );
        },
        redirect: (BuildContext context, GoRouterState state) {
          return redirectWhenLoggedIn(context, state);
        },
      ),
      GoRoute(
        path: welcomePath,
        pageBuilder: (context, state) {
          _log.finer('GoRouter changed to welcomePath');
          return getPage(
            child: const WelcomeScreen(),
            state: state,
          );
        },
        redirect: (BuildContext context, GoRouterState state) {
          return redirectWhenLoggedIn(context, state);
        },
      ),
      GoRoute(
        path: registerPath,
        pageBuilder: (context, state) {
          _log.finer('GoRouter changed to registerPath');
          return getPage(
            child: const RegisterUserScreen(),
            state: state,
          );
        },
        redirect: (BuildContext context, GoRouterState state) {
          return redirectWhenLoggedIn(context, state);
        },
      ),
      GoRoute(
        path: registerCodePath,
        pageBuilder: (context, state) {
          _log.finer('GoRouter changed to registerCodePath');
          return getPage(
            child: const RegisterCodeScreen(),
            state: state,
          );
        },
        redirect: (BuildContext context, GoRouterState state) {
          return redirectWhenLoggedIn(context, state);
        },
      ),
      GoRoute(
        path: selectTeamPath,
        pageBuilder: (context, state) {
          _log.finer('GoRouter changed to registerTeamPath');
          return getPage(
            child: const SelectCurrentTeamScreen(),
            state: state,
          );
        },
        redirect: (BuildContext context, GoRouterState state) {
          return redirectWhenNotLoggedIn(context, state);
        },
      ),
      GoRoute(
        path: registerTeamPath,
        pageBuilder: (context, state) {
          _log.finer('GoRouter changed to registerTeamPath');
          return getPage(
            child: const RegisterNewTeamScreen(),
            state: state,
          );
        },
        redirect: (BuildContext context, GoRouterState state) {
          return redirectWhenNotLoggedIn(context, state);
        },
      ),
      GoRoute(
        path: createProfilePath,
        pageBuilder: (context, state) {
          _log.finer('GoRouter changed to createProfilePath');
          return getPage(
            child: const CreateProfileScreen(),
            state: state,
          );
        },
        redirect: (BuildContext context, GoRouterState state) {
          return redirectWhenNotLoggedIn(context, state);
        },
      ),
      GoRoute(
        parentNavigatorKey: parentNavigatorKey,
        path: rootDetailPath,
        pageBuilder: (context, state) {
          _log.finer('GoRouter changed to rootDetailPath');
          return getPage(
            child: const HomePage(),
            state: state,
          );
        },
      ),
    ];
    GoRouter.optionURLReflectsImperativeAPIs = false;

    router = GoRouter(
      observers: [MsgrNavigatorObserver()],
      navigatorKey: parentNavigatorKey,
      initialLocation: welcomePath,
      /*errorBuilder: (context, state) {
        return ErrorScreen(error: state.error);
      },*/
      debugLogDiagnostics: kGoRouterDiagnostic,
      onException: (context, state, router) {
        _log.severe('GoRouter Exception: ${state.error}');
      },
      routes: routes,
    );
  }

  static Page getPage({
    required Widget child,
    required GoRouterState state,
  }) {
    return MaterialPage(
      key: state.pageKey,
      child: child,
    );
  }
}

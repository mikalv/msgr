import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/authentication/auth_state.dart';
import 'package:messngr/redux/team_state.dart';
import 'package:messngr/redux/ui/ui_state.dart';
import 'package:messngr/ui/pages/home_page/home_page.dart';
import 'package:messngr/utils/flutter_redux.dart';
import 'package:redux/redux.dart';

void main() {
  late Store<AppState> store;

  setUp(() {
    final team = Team.raw(
      id: 'team-1',
      name: 'Flow',
      description: 'Test team',
      creatorUid: 'user-1',
      createdAt: DateTime(2023, 1, 1),
      updatedAt: DateTime(2023, 1, 1),
    );

    final authState = AuthState(
      kIsLoggedIn: true,
      currentUser: null,
      currentProfile: null,
      currentTeam: team,
      currentTeamName: team.name,
      teams: [team],
      teamAccessToken: 'token',
      isLoading: false,
    );

    final teamState = TeamState(
      selectedTeam: team,
      rooms: const [],
      conversations: const [],
    );

    final appState = AppState(
      authState: authState,
      teamState: teamState,
      currentRoute: AppNavigation.dashboardPath,
      uiState: UiState(
        windowPosition: Offset.zero,
        windowSize: const Size(800, 600),
      ),
    );

    store = Store<AppState>(
      (state, action) => state,
      initialState: appState,
    );
  });

  Future<void> _pumpHomePage(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      StoreProvider<AppState>(
        store: store,
        child: const MaterialApp(
          home: HomePage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('renders compact layout under tablet breakpoint',
      (tester) async {
    await _pumpHomePage(tester, const Size(640, 900));

    expect(find.byKey(const Key('home_compact_layout')), findsOneWidget);
    expect(find.byKey(const Key('home_medium_layout')), findsNothing);
    expect(find.byKey(const Key('home_large_layout')), findsNothing);
  });

  testWidgets('renders tablet layout when width is medium', (tester) async {
    await _pumpHomePage(tester, const Size(1024, 900));

    expect(find.byKey(const Key('home_compact_layout')), findsNothing);
    expect(find.byKey(const Key('home_medium_layout')), findsOneWidget);
    expect(find.byKey(const Key('home_large_layout')), findsNothing);
  });

  testWidgets('renders desktop layout at wide breakpoints', (tester) async {
    await _pumpHomePage(tester, const Size(1400, 900));

    expect(find.byKey(const Key('home_large_layout')), findsOneWidget);
    expect(find.byKey(const Key('home_large_sidebar')), findsOneWidget);
  });
}

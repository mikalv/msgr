import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/features/auth/auth_gate.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/profile/profile_actions.dart';
import 'package:messngr/redux/team_state.dart';
import 'package:messngr/redux/ui/ui_state.dart';
import 'package:messngr/services/api/chat_api.dart';
import 'package:messngr/services/api/profile_api.dart';
import 'package:messngr/ui/widgets/profile/profile_mode_switcher.dart';
import 'package:messngr/utils/flutter_redux.dart';
import 'package:provider/provider.dart';
import 'package:redux/redux.dart';

void main() {
  group('ProfileModeSwitcher', () {
    late Store<AppState> store;
    late List<dynamic> dispatched;
    late Profile workProfile;
    late Profile familyProfile;

    setUp(() {
      dispatched = [];
      workProfile = Profile(
        id: 'work-1',
        username: 'work',
        name: 'Jobb',
        slug: 'jobb',
        mode: ProfileMode.work,
        isActive: true,
      );
      familyProfile = Profile(
        id: 'family-1',
        username: 'family',
        name: 'Familie',
        slug: 'familie',
        mode: ProfileMode.family,
      );

      final authState = AuthState(
        kIsLoggedIn: true,
        currentUser: null,
        currentProfile: workProfile,
        currentTeam: null,
        currentTeamName: 'team-1',
        teamAccessToken: 'token',
        teams: const [],
        isLoading: false,
      );
      final teamState = TeamState(
        selectedTeam: null,
        profiles: [workProfile, familyProfile],
      );
      final uiState = UiState(
        windowPosition: Offset.zero,
        windowSize: const Size(800, 600),
      );
      final initialState = AppState(
        authState: authState,
        teamState: teamState,
        currentRoute: '/',
        currentProfile: workProfile,
        uiState: uiState,
        error: null,
      );

      final middleware = <Middleware<AppState>>[
        TypedMiddleware<AppState, RefreshProfilesAction>((store, action, next) {
          dispatched.add(action);
          next(action);
          store.dispatch(
            RefreshProfilesSuccessAction(profiles: [workProfile, familyProfile]),
          );
        }),
        TypedMiddleware<AppState, SwitchProfileAction>((store, action, next) {
          dispatched.add(action);
          action.completer.complete(
            ProfileSwitchResult(
              profile: familyProfile.copyWith(isActive: true),
              identity: AccountIdentity(
                accountId: 'acct',
                profileId: familyProfile.id,
                noiseToken: 'noise-new',
              ),
              device: null,
            ),
          );
          store.dispatch(
            SwitchProfileSuccessAction(
              profile: familyProfile.copyWith(isActive: true),
              identity: AccountIdentity(
                accountId: 'acct',
                profileId: familyProfile.id,
                noiseToken: 'noise-new',
              ),
            ),
          );
          next(action);
        }),
      ];

      store = Store<AppState>(
        (state, action) => state,
        initialState: initialState,
        middleware: middleware,
      );
    });

    Widget _buildHarness({ProfileMode? filter, ValueChanged<ProfileMode?>? onFilterChanged, bool listen = true}) {
      var updatedIdentity = AccountIdentity(
        accountId: 'acct',
        profileId: workProfile.id,
        noiseToken: 'noise-token',
      );
      final session = AuthSession(
        identity: updatedIdentity,
        signOut: () async {},
        updateIdentity: (identity, {String? displayName}) async {
          updatedIdentity = identity;
        },
      );
      return MultiProvider(
        providers: [
          Provider<AuthSession>.value(value: session),
        ],
        child: StoreProvider<AppState>(
          store: store,
          child: MaterialApp(
            home: Scaffold(
              body: ProfileModeSwitcher(
                initialFilter: filter,
                onFilterChanged: onFilterChanged,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders profile chips and filter options', (tester) async {
      bool? filterMode;
      await tester.pumpWidget(_buildHarness(onFilterChanged: (mode) {
        filterMode = mode;
      }));
      await tester.pumpAndSettle();

      expect(find.text('Jobb'), findsOneWidget);
      expect(find.text('Familie'), findsOneWidget);
      expect(find.text('Alle innbokser'), findsOneWidget);

      await tester.tap(find.text('Familie'));
      await tester.pump();
      expect(dispatched.whereType<SwitchProfileAction>(), isNotEmpty);

      await tester.tap(find.text('Privat'));
      await tester.pump();
      expect(filterMode, ProfileMode.private);
    });
  });
}

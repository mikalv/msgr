import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:core/providers/auth_state_provider.dart';

void main() {
  group('SimpleAuthState', () {
    test('default construction has all fields null and isLoading false', () {
      const state = SimpleAuthState();
      expect(state.accountId, isNull);
      expect(state.profileId, isNull);
      expect(state.email, isNull);
      expect(state.displayName, isNull);
      expect(state.accessToken, isNull);
      expect(state.refreshToken, isNull);
      expect(state.isLoading, false);
    });

    test('isLoggedIn returns true when accountId and profileId are set', () {
      const state = SimpleAuthState(
        accountId: 'acc-1',
        profileId: 'prof-1',
      );
      expect(state.isLoggedIn, true);
    });

    test('isLoggedIn returns false when accountId is null', () {
      const state = SimpleAuthState(profileId: 'prof-1');
      expect(state.isLoggedIn, false);
    });

    test('isLoggedIn returns false when profileId is null', () {
      const state = SimpleAuthState(accountId: 'acc-1');
      expect(state.isLoggedIn, false);
    });

    test('isLoggedIn does not require accessToken (code does not check it)', () {
      // Note: the actual implementation only checks accountId and profileId.
      const state = SimpleAuthState(
        accountId: 'acc-1',
        profileId: 'prof-1',
        // accessToken intentionally omitted
      );
      expect(state.isLoggedIn, true);
    });

    test('copyWith preserves existing values when no arguments given', () {
      const original = SimpleAuthState(
        accountId: 'acc-1',
        profileId: 'prof-1',
        email: 'test@example.com',
        displayName: 'Test',
        accessToken: 'token-a',
        refreshToken: 'token-r',
        isLoading: true,
      );
      final copy = original.copyWith();
      expect(copy.accountId, 'acc-1');
      expect(copy.profileId, 'prof-1');
      expect(copy.email, 'test@example.com');
      expect(copy.displayName, 'Test');
      expect(copy.accessToken, 'token-a');
      expect(copy.refreshToken, 'token-r');
      expect(copy.isLoading, true);
    });

    test('copyWith overrides specified fields', () {
      const original = SimpleAuthState(
        accountId: 'acc-1',
        profileId: 'prof-1',
        accessToken: 'old-token',
      );
      final updated = original.copyWith(
        accessToken: 'new-token',
        displayName: 'Updated Name',
      );
      expect(updated.accountId, 'acc-1');
      expect(updated.accessToken, 'new-token');
      expect(updated.displayName, 'Updated Name');
    });
  });

  group('SimpleAuthNotifier', () {
    setUp(() {
      // Provide empty SharedPreferences for each test
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state has isLoading true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(simpleAuthProvider);
      expect(state.isLoading, true);
    });

    test('login sets all fields', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(simpleAuthProvider.notifier);
      await notifier.login(
        accountId: 'acc-1',
        profileId: 'prof-1',
        email: 'user@test.com',
        displayName: 'User',
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
      );

      final state = container.read(simpleAuthProvider);
      expect(state.accountId, 'acc-1');
      expect(state.profileId, 'prof-1');
      expect(state.email, 'user@test.com');
      expect(state.displayName, 'User');
      expect(state.accessToken, 'access-123');
      expect(state.refreshToken, 'refresh-456');
      expect(state.isLoggedIn, true);
    });

    test('logout clears state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(simpleAuthProvider.notifier);
      await notifier.login(
        accountId: 'acc-1',
        profileId: 'prof-1',
        accessToken: 'tok',
      );
      await notifier.logout();

      final state = container.read(simpleAuthProvider);
      expect(state.accountId, isNull);
      expect(state.profileId, isNull);
      expect(state.email, isNull);
      expect(state.displayName, isNull);
      expect(state.accessToken, isNull);
      expect(state.refreshToken, isNull);
      expect(state.isLoggedIn, false);
      expect(state.isLoading, false);
    });

    test('updateTokens updates tokens without changing other fields', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(simpleAuthProvider.notifier);
      await notifier.login(
        accountId: 'acc-1',
        profileId: 'prof-1',
        email: 'old@test.com',
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
      );

      await notifier.updateTokens(
        accessToken: 'new-access',
        refreshToken: 'new-refresh',
      );

      final state = container.read(simpleAuthProvider);
      expect(state.accountId, 'acc-1');
      expect(state.profileId, 'prof-1');
      expect(state.email, 'old@test.com');
      expect(state.accessToken, 'new-access');
      expect(state.refreshToken, 'new-refresh');
    });

    test('loads persisted auth from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'auth_account_id': 'persisted-acc',
        'auth_profile_id': 'persisted-prof',
        'auth_email': 'persisted@test.com',
        'auth_display_name': 'Persisted User',
        'auth_access_token': 'persisted-token',
        'auth_refresh_token': 'persisted-refresh',
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Wait for async _loadFromPrefs to complete
      await Future.delayed(const Duration(milliseconds: 100));

      final state = container.read(simpleAuthProvider);
      expect(state.accountId, 'persisted-acc');
      expect(state.profileId, 'persisted-prof');
      expect(state.email, 'persisted@test.com');
      expect(state.isLoading, false);
    });

    test('isSimpleAuthLoggedInProvider reflects login state', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(isSimpleAuthLoggedInProvider), false);

      await container.read(simpleAuthProvider.notifier).login(
            accountId: 'a',
            profileId: 'p',
          );

      expect(container.read(isSimpleAuthLoggedInProvider), true);
    });
  });
}

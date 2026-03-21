import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple auth state for header-based authentication (X-Account-Id, X-Profile-Id).
///
/// This is separate from the existing [AuthState] in auth_provider.dart which
/// uses JWT tokens via libmsgr. This provider works with the direct REST API
/// on dev.msgr.no.
class SimpleAuthState {
  const SimpleAuthState({
    this.accountId,
    this.profileId,
    this.email,
    this.displayName,
    this.accessToken,
    this.refreshToken,
    this.isLoading = false,
  });

  final String? accountId;
  final String? profileId;
  final String? email;
  final String? displayName;

  /// JWT access token (short-lived).
  final String? accessToken;

  /// JWT refresh token (long-lived).
  final String? refreshToken;

  final bool isLoading;

  bool get isLoggedIn => accountId != null && profileId != null;

  SimpleAuthState copyWith({
    String? accountId,
    String? profileId,
    String? email,
    String? displayName,
    String? accessToken,
    String? refreshToken,
    bool? isLoading,
  }) {
    return SimpleAuthState(
      accountId: accountId ?? this.accountId,
      profileId: profileId ?? this.profileId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SimpleAuthNotifier extends StateNotifier<SimpleAuthState> {
  SimpleAuthNotifier() : super(const SimpleAuthState(isLoading: true)) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final accountId = prefs.getString('auth_account_id');
    final profileId = prefs.getString('auth_profile_id');
    final email = prefs.getString('auth_email');
    final displayName = prefs.getString('auth_display_name');
    final accessToken = prefs.getString('auth_access_token');
    final refreshToken = prefs.getString('auth_refresh_token');
    if (accountId != null && profileId != null) {
      state = SimpleAuthState(
        accountId: accountId,
        profileId: profileId,
        email: email,
        displayName: displayName,
        accessToken: accessToken,
        refreshToken: refreshToken,
        isLoading: false,
      );
    } else {
      state = const SimpleAuthState(isLoading: false);
    }
  }

  Future<void> login({
    required String accountId,
    required String profileId,
    String? email,
    String? displayName,
    String? accessToken,
    String? refreshToken,
  }) async {
    state = SimpleAuthState(
      accountId: accountId,
      profileId: profileId,
      email: email,
      displayName: displayName,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_account_id', accountId);
    await prefs.setString('auth_profile_id', profileId);
    if (email != null) await prefs.setString('auth_email', email);
    if (displayName != null) await prefs.setString('auth_display_name', displayName);
    if (accessToken != null) await prefs.setString('auth_access_token', accessToken);
    if (refreshToken != null) await prefs.setString('auth_refresh_token', refreshToken);
  }

  /// Update stored tokens (e.g. after a refresh).
  Future<void> updateTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    state = state.copyWith(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_access_token', accessToken);
    if (refreshToken != null) {
      await prefs.setString('auth_refresh_token', refreshToken);
    }
  }

  Future<void> logout() async {
    state = const SimpleAuthState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_account_id');
    await prefs.remove('auth_profile_id');
    await prefs.remove('auth_email');
    await prefs.remove('auth_display_name');
    await prefs.remove('auth_access_token');
    await prefs.remove('auth_refresh_token');
    await prefs.remove('last_team_slug');
    await prefs.remove('last_channel_id');
  }
}

final simpleAuthProvider =
    StateNotifierProvider<SimpleAuthNotifier, SimpleAuthState>((ref) {
  return SimpleAuthNotifier();
});

final isSimpleAuthLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(simpleAuthProvider).isLoggedIn;
});

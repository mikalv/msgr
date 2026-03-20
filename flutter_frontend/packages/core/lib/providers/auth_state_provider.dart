import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

  final String? accountId;
  final String? profileId;
  final String? email;

  bool get isLoggedIn => accountId != null && profileId != null;

  SimpleAuthState copyWith({
    String? accountId,
    String? profileId,
    String? email,
  }) {
    return SimpleAuthState(
      accountId: accountId ?? this.accountId,
      profileId: profileId ?? this.profileId,
      email: email ?? this.email,
    );
  }
}

class SimpleAuthNotifier extends StateNotifier<SimpleAuthState> {
  SimpleAuthNotifier() : super(const SimpleAuthState());

  void login({
    required String accountId,
    required String profileId,
    String? email,
  }) {
    state = SimpleAuthState(
      accountId: accountId,
      profileId: profileId,
      email: email,
    );
  }

  void logout() {
    state = const SimpleAuthState();
  }
}

final simpleAuthProvider =
    StateNotifierProvider<SimpleAuthNotifier, SimpleAuthState>((ref) {
  return SimpleAuthNotifier();
});

final isSimpleAuthLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(simpleAuthProvider).isLoggedIn;
});

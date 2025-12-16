import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libmsgr/libmsgr.dart';

/// Auth state class holding authentication data
class AuthState {
  final User? currentUser;
  final Team? currentTeam;
  final Profile? currentProfile;
  final String? teamAccessToken;
  final List<Team> teams;
  final bool isLoading;
  final Exception? error;

  // Registration/login pending fields
  final String? pendingMsisdn;
  final String? pendingEmail;
  final String? pendingTeam;
  final String? pendingChallengeId;
  final String? pendingChannel;
  final String? pendingTargetHint;
  final String? pendingDebugCode;
  final DateTime? pendingChallengeExpiresAt;
  final String? pendingDisplayName;

  bool get isLoggedIn => currentUser != null;
  bool get hasSelectedTeam => teamAccessToken != null;

  const AuthState({
    this.currentUser,
    this.currentTeam,
    this.currentProfile,
    this.teamAccessToken,
    this.teams = const [],
    this.isLoading = false,
    this.error,
    this.pendingMsisdn,
    this.pendingEmail,
    this.pendingTeam,
    this.pendingChallengeId,
    this.pendingChannel,
    this.pendingTargetHint,
    this.pendingDebugCode,
    this.pendingChallengeExpiresAt,
    this.pendingDisplayName,
  });

  AuthState copyWith({
    User? currentUser,
    Team? currentTeam,
    Profile? currentProfile,
    String? teamAccessToken,
    List<Team>? teams,
    bool? isLoading,
    Exception? error,
    String? pendingMsisdn,
    String? pendingEmail,
    String? pendingTeam,
    String? pendingChallengeId,
    String? pendingChannel,
    String? pendingTargetHint,
    String? pendingDebugCode,
    DateTime? pendingChallengeExpiresAt,
    String? pendingDisplayName,
  }) {
    return AuthState(
      currentUser: currentUser ?? this.currentUser,
      currentTeam: currentTeam ?? this.currentTeam,
      currentProfile: currentProfile ?? this.currentProfile,
      teamAccessToken: teamAccessToken ?? this.teamAccessToken,
      teams: teams ?? this.teams,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      pendingMsisdn: pendingMsisdn ?? this.pendingMsisdn,
      pendingEmail: pendingEmail ?? this.pendingEmail,
      pendingTeam: pendingTeam ?? this.pendingTeam,
      pendingChallengeId: pendingChallengeId ?? this.pendingChallengeId,
      pendingChannel: pendingChannel ?? this.pendingChannel,
      pendingTargetHint: pendingTargetHint ?? this.pendingTargetHint,
      pendingDebugCode: pendingDebugCode ?? this.pendingDebugCode,
      pendingChallengeExpiresAt:
          pendingChallengeExpiresAt ?? this.pendingChallengeExpiresAt,
      pendingDisplayName: pendingDisplayName ?? this.pendingDisplayName,
    );
  }
}

/// Auth notifier class
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  /// Login with email or phone
  Future<void> loginWithEmailOrPhone(String emailOrPhone) async {
    state = state.copyWith(isLoading: true);
    try {
      // TODO: Implement login logic using LibMsgr
      // For now, this is a placeholder
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e as Exception,
      );
    }
  }

  /// Verify OTP code
  Future<void> verifyCode(String code) async {
    state = state.copyWith(isLoading: true);
    try {
      // TODO: Implement code verification logic
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e as Exception,
      );
    }
  }

  /// Select a team
  Future<void> selectTeam(Team team) async {
    state = state.copyWith(isLoading: true);
    try {
      // TODO: Implement team selection logic
      // Get team access token from backend
      state = state.copyWith(
        currentTeam: team,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e as Exception,
      );
    }
  }

  /// Logout
  Future<void> logout() async {
    state = const AuthState();
  }

  /// Set pending registration/login data
  void setPendingData({
    String? msisdn,
    String? email,
    String? team,
    String? challengeId,
    String? channel,
    String? targetHint,
    String? debugCode,
    DateTime? challengeExpiresAt,
    String? displayName,
  }) {
    state = state.copyWith(
      pendingMsisdn: msisdn,
      pendingEmail: email,
      pendingTeam: team,
      pendingChallengeId: challengeId,
      pendingChannel: channel,
      pendingTargetHint: targetHint,
      pendingDebugCode: debugCode,
      pendingChallengeExpiresAt: challengeExpiresAt,
      pendingDisplayName: displayName,
    );
  }
}

/// Auth state provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

/// Convenience providers for specific auth state
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).currentUser;
});

final currentTeamProvider = Provider<Team?>((ref) {
  return ref.watch(authProvider).currentTeam;
});

final currentProfileProvider = Provider<Profile?>((ref) {
  return ref.watch(authProvider).currentProfile;
});

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoggedIn;
});

final hasSelectedTeamProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).hasSelectedTeam;
});

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:core/providers/api_providers.dart';
import 'package:core/services/api/chat_api.dart';

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
  AuthNotifier(this._ref) : super(const AuthState()) {
    _loadPersistedSession();
  }

  final Ref _ref;

  // Storage keys for session persistence
  static const String _keyCurrentUser = 'auth_current_user';
  static const String _keyCurrentTeam = 'auth_current_team';
  static const String _keyCurrentProfile = 'auth_current_profile';
  static const String _keyTeamAccessToken = 'auth_team_access_token';
  static const String _keyTeams = 'auth_teams';

  /// Load persisted session from secure storage
  Future<void> _loadPersistedSession() async {
    try {
      final storage = LibMsgr().secureStorage;

      final userJson = await storage.readValue(_keyCurrentUser);
      final teamJson = await storage.readValue(_keyCurrentTeam);
      final profileJson = await storage.readValue(_keyCurrentProfile);
      final teamAccessToken = await storage.readValue(_keyTeamAccessToken);
      final teamsJson = await storage.readValue(_keyTeams);

      User? user;
      Team? team;
      Profile? profile;
      List<Team> teams = [];

      if (userJson != null) {
        user = User.fromJson(jsonDecode(userJson));
      }

      if (teamJson != null) {
        team = Team.fromJson(jsonDecode(teamJson));
      }

      if (profileJson != null) {
        profile = Profile.fromJson(jsonDecode(profileJson));
      }

      if (teamsJson != null) {
        final teamsList = jsonDecode(teamsJson) as List;
        teams = teamsList.map((e) => Team.fromJson(e)).toList();
      }

      if (user != null) {
        state = state.copyWith(
          currentUser: user,
          currentTeam: team,
          currentProfile: profile,
          teamAccessToken: teamAccessToken,
          teams: teams,
        );
      }
    } catch (e) {
      // If loading fails, just start with empty state
      state = const AuthState();
    }
  }

  /// Persist current session to secure storage
  Future<void> _persistSession() async {
    try {
      final storage = LibMsgr().secureStorage;

      if (state.currentUser != null) {
        await storage.writeValue(
          _keyCurrentUser,
          jsonEncode(state.currentUser!.toJson()),
        );
      } else {
        await storage.deleteKey(_keyCurrentUser);
      }

      if (state.currentTeam != null) {
        await storage.writeValue(
          _keyCurrentTeam,
          jsonEncode(state.currentTeam!.toJson()),
        );
      } else {
        await storage.deleteKey(_keyCurrentTeam);
      }

      if (state.currentProfile != null) {
        await storage.writeValue(
          _keyCurrentProfile,
          jsonEncode(state.currentProfile!.toJson()),
        );
      } else {
        await storage.deleteKey(_keyCurrentProfile);
      }

      if (state.teamAccessToken != null) {
        await storage.writeValue(_keyTeamAccessToken, state.teamAccessToken!);
      } else {
        await storage.deleteKey(_keyTeamAccessToken);
      }

      if (state.teams.isNotEmpty) {
        await storage.writeValue(
          _keyTeams,
          jsonEncode(state.teams.map((e) => e.toJson()).toList()),
        );
      } else {
        await storage.deleteKey(_keyTeams);
      }
    } catch (e) {
      // Log error but don't fail
      // TODO: Add proper error logging
    }
  }

  /// Login with email or phone
  Future<void> loginWithEmailOrPhone(String emailOrPhone,
      {String? displayName}) async {
    state = state.copyWith(isLoading: true);
    try {
      final reg = RegistrationService();

      // Determine if it's email or phone number
      final isEmail = emailOrPhone.contains('@');
      AuthChallenge? challenge;

      if (isEmail) {
        challenge = await reg.requestForSignInCodeEmail(emailOrPhone);
      } else {
        challenge = await reg.requestForSignInCodeMsisdn(emailOrPhone);
      }

      if (challenge != null) {
        state = state.copyWith(
          pendingChallengeId: challenge.id,
          pendingEmail: isEmail ? emailOrPhone : null,
          pendingMsisdn: isEmail ? null : emailOrPhone,
          pendingChannel: challenge.channel,
          pendingTargetHint: challenge.targetHint,
          pendingDebugCode: challenge.debugCode,
          pendingChallengeExpiresAt: challenge.expiresAt,
          pendingDisplayName: displayName,
          isLoading: false,
        );
      } else {
        throw Exception('Failed to request sign-in code');
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e as Exception,
      );
      rethrow;
    }
  }

  /// Verify OTP code
  Future<void> verifyCode(String code) async {
    state = state.copyWith(isLoading: true);
    try {
      final reg = RegistrationService();
      final challengeId = state.pendingChallengeId;
      final displayName = state.pendingDisplayName;

      if (challengeId == null) {
        throw Exception('No pending challenge ID');
      }

      User? user;

      if (state.pendingMsisdn != null) {
        // Phone login
        user = await reg.submitMsisdnCodeForToken(
          challengeId: challengeId,
          code: code,
          displayName: displayName,
        );
      } else if (state.pendingEmail != null) {
        // Email login
        user = await reg.submitEmailCodeForToken(
          challengeId: challengeId,
          code: code,
          displayName: displayName,
        );
      } else {
        throw Exception('No pending email or phone number');
      }

      if (user != null) {
        // Fetch teams for the user
        final teams = await reg.listMyTeams(user.accessToken);

        state = state.copyWith(
          currentUser: user,
          teams: teams,
          isLoading: false,
          // Clear pending registration data
          pendingChallengeId: null,
          pendingEmail: null,
          pendingMsisdn: null,
          pendingChannel: null,
          pendingTargetHint: null,
          pendingDebugCode: null,
          pendingChallengeExpiresAt: null,
          pendingDisplayName: null,
        );

        // Persist the session
        await _persistSession();
      } else {
        throw Exception('Failed to verify code');
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e as Exception,
      );
      rethrow;
    }
  }

  /// Select a team
  Future<void> selectTeam(Team team) async {
    state = state.copyWith(isLoading: true);
    try {
      final reg = RegistrationService();
      final currentUser = state.currentUser;

      if (currentUser == null) {
        throw Exception('No current user');
      }

      // Get team access token from backend
      final response = await reg.selectTeamForToken(
        teamName: team.name,
        token: currentUser.accessToken,
      );

      if (response == null) {
        throw Exception('Failed to select team');
      }

      final teamAccessToken = response['teamAccessToken'] as String?;
      if (teamAccessToken == null) {
        throw Exception('No team access token in response');
      }

      state = state.copyWith(
        currentTeam: team,
        teamAccessToken: teamAccessToken,
        isLoading: false,
      );

      // Persist the session
      await _persistSession();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e as Exception,
      );
      rethrow;
    }
  }

  /// Logout
  Future<void> logout() async {
    state = const AuthState();
    // Clear persisted session
    final storage = LibMsgr().secureStorage;
    await storage.deleteKey(_keyCurrentUser);
    await storage.deleteKey(_keyCurrentTeam);
    await storage.deleteKey(_keyCurrentProfile);
    await storage.deleteKey(_keyTeamAccessToken);
    await storage.deleteKey(_keyTeams);
  }

  /// Set current user
  void setCurrentUser(User user) {
    state = state.copyWith(currentUser: user);
    _persistSession();
  }

  /// Set current team
  void setCurrentTeam(Team team) {
    state = state.copyWith(currentTeam: team);
    _persistSession();
  }

  /// Set current profile
  void setCurrentProfile(Profile profile) {
    state = state.copyWith(currentProfile: profile);
    _persistSession();
  }

  /// Set teams list
  void setTeams(List<Team> teams) {
    state = state.copyWith(teams: teams);
    _persistSession();
  }

  /// Switch to a different profile
  Future<void> switchProfile({
    required AccountIdentity identity,
    required String profileId,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final api = _ref.read(profileApiProvider);
      final result = await api.switchProfile(
        identity: identity,
        profileId: profileId,
      );

      state = state.copyWith(
        currentProfile: result.profile,
        isLoading: false,
      );

      // Persist the session
      await _persistSession();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e as Exception,
      );
      rethrow;
    }
  }

  /// List all profiles for current user
  Future<List<Profile>> listProfiles({
    required AccountIdentity identity,
  }) async {
    final api = _ref.read(profileApiProvider);
    return await api.listProfiles(identity: identity);
  }

  /// Update profile
  Future<Profile> updateProfile({
    required AccountIdentity identity,
    required String profileId,
    required Map<String, dynamic> changes,
  }) async {
    final api = _ref.read(profileApiProvider);
    final updated = await api.updateProfile(
      identity: identity,
      profileId: profileId,
      changes: changes,
    );

    // Update state if this is the current profile
    if (state.currentProfile?.id == profileId) {
      state = state.copyWith(currentProfile: updated);
      await _persistSession();
    }

    return updated;
  }

  /// Delete profile
  Future<void> deleteProfile({
    required AccountIdentity identity,
    required String profileId,
  }) async {
    final api = _ref.read(profileApiProvider);
    await api.deleteProfile(
      identity: identity,
      profileId: profileId,
    );

    // Clear current profile if it was deleted
    if (state.currentProfile?.id == profileId) {
      state = state.copyWith(currentProfile: null);
      await _persistSession();
    }
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
  return AuthNotifier(ref);
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

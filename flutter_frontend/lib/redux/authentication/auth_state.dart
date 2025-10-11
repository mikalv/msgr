import 'package:libmsgr/libmsgr.dart';

/// Represents the authentication state within the application.
/// This class holds the necessary information to manage and track
/// the authentication status of a user.
class AuthState {
  final bool _kIsLoggedIn;

  final User? currentUser;
  final Team? currentTeam;
  final Profile? currentProfile;

  final String? currentTeamName;
  final String? teamAccessToken;
  final List<Team> teams;

  // Pending fields
  final String? pendingMsisdn;
  final String? pendingEmail;
  final String? pendingTeam;
  final String? pendingChallengeId;
  final String? pendingChannel;
  final String? pendingTargetHint;
  final String? pendingDebugCode;
  final DateTime? pendingChallengeExpiresAt;
  final String? pendingDisplayName;

  bool isLoading;
  bool _kHasSelectedTeam = false;
  dynamic lastError;

  get isLoggedIn => _kIsLoggedIn;
  get hasSelectedTeam => _kHasSelectedTeam;

  AuthState(
      {required bool kIsLoggedIn,
      required this.currentUser,
      required this.currentProfile,
      required this.teams,
      required this.isLoading,
      this.currentTeam,
      this.pendingMsisdn,
      this.pendingEmail,
      this.pendingTeam,
      this.pendingChallengeId,
      this.pendingChannel,
      this.pendingTargetHint,
      this.pendingDebugCode,
      this.pendingChallengeExpiresAt,
      this.pendingDisplayName,
      this.currentTeamName,
      this.teamAccessToken})
      : _kIsLoggedIn = kIsLoggedIn {
    if (teamAccessToken != null) {
      _kHasSelectedTeam = true;
    }
  }

  @override
  bool operator ==(other) =>
      identical(this, other) ||
      other is AuthState &&
          currentUser == other.currentUser &&
          currentProfile == other.currentProfile &&
          currentTeam == other.currentTeam &&
          currentTeamName == other.currentTeamName &&
          _kIsLoggedIn == other._kIsLoggedIn &&
          teams == other.teams &&
          teamAccessToken == other.teamAccessToken &&
          isLoading == other.isLoading &&
          pendingEmail == other.pendingEmail &&
          pendingMsisdn == other.pendingMsisdn &&
          pendingTeam == other.pendingTeam &&
          pendingChallengeId == other.pendingChallengeId &&
          pendingChannel == other.pendingChannel &&
          pendingTargetHint == other.pendingTargetHint &&
          pendingDebugCode == other.pendingDebugCode &&
          pendingChallengeExpiresAt == other.pendingChallengeExpiresAt &&
          pendingDisplayName == other.pendingDisplayName;

  @override
  int get hashCode =>
      super.hashCode ^
      currentUser.hashCode ^
      currentProfile.hashCode ^
      currentTeam.hashCode ^
      currentTeamName.hashCode ^
      _kIsLoggedIn.hashCode ^
      teams.hashCode ^
      teamAccessToken.hashCode ^
      isLoading.hashCode ^
      pendingEmail.hashCode ^
      pendingMsisdn.hashCode ^
      pendingTeam.hashCode ^
      pendingChallengeId.hashCode ^
      pendingChannel.hashCode ^
      pendingTargetHint.hashCode ^
      pendingDebugCode.hashCode ^
      pendingChallengeExpiresAt.hashCode ^
      pendingDisplayName.hashCode;

  @override
  String toString() {
    return 'AuthState{isLoggedIn=$_kIsLoggedIn, '
        'hasSelectedTeam=$_kHasSelectedTeam, '
        'currentUser: $currentUser, '
        'currentTeamName: $currentTeamName}';
  }

  factory AuthState.fromJson(dynamic json) {
    if (json == null) {
      return AuthState(
        kIsLoggedIn: false,
        currentUser: null,
        currentProfile: null,
        currentTeam: null,
        currentTeamName: null,
        teams: <Team>[],
        isLoading: true,
      );
    }
    final bJson = json as Map<String, dynamic>;
    User? user;
    if (bJson['currentUser'] == null) {
      user = null;
    } else {
      user = User.fromJson(bJson['currentUser']);
    }
    Profile? profile;
    if (bJson['currentProfile'] == null) {
      profile = null;
    } else {
      profile = Profile.fromJson(bJson['currentProfile']);
    }
    Team? team;
    if (bJson['currentTeam'] == null) {
      team = null;
    } else {
      team = Team.fromJson(bJson['currentTeam']);
    }
    return AuthState(
        kIsLoggedIn: bJson['kIsLoggedIn'] as bool,
        currentUser: user,
        currentProfile: profile,
        currentTeam: team,
        currentTeamName: bJson['currentTeamName'],
        teamAccessToken: bJson['teamAccessToken'],
        pendingEmail: bJson['pendingEmail'],
        pendingMsisdn: bJson['pendingMsisdn'],
        pendingTeam: bJson['pendingTeam'],
        pendingChallengeId: bJson['pendingChallengeId'],
        pendingChannel: bJson['pendingChannel'],
        pendingTargetHint: bJson['pendingTargetHint'],
        pendingDebugCode: bJson['pendingDebugCode'],
        pendingChallengeExpiresAt: bJson['pendingChallengeExpiresAt'] == null
            ? null
            : DateTime.parse(bJson['pendingChallengeExpiresAt']),
        pendingDisplayName: bJson['pendingDisplayName'],
        isLoading: false,
        teams: bJson['teams'].map<Team>((x) => Team.fromJson(x)).toList());
  }

  Map<String, dynamic> toJson() => {
        'kIsLoggedIn': _kIsLoggedIn,
        'currentUser': currentUser,
        'currentProfile': currentProfile,
        'currentTeam': currentTeam,
        'currentTeamName': currentTeam?.name,
        'teamAccessToken': teamAccessToken,
        'pendingMsisdn': pendingMsisdn,
        'pendingEmail': pendingEmail,
        'pendingTeam': pendingTeam,
        'pendingChallengeId': pendingChallengeId,
        'pendingChannel': pendingChannel,
        'pendingTargetHint': pendingTargetHint,
        'pendingDebugCode': pendingDebugCode,
        'pendingChallengeExpiresAt':
            pendingChallengeExpiresAt?.toIso8601String(),
        'pendingDisplayName': pendingDisplayName,
        'teams': teams,
      };
}

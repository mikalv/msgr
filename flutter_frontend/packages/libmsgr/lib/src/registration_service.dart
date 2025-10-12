import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/models/profile.dart';
import 'package:libmsgr/src/models/team.dart';
import 'package:libmsgr/src/models/user.dart';
import 'package:libmsgr_core/libmsgr_core.dart';
import 'package:logging/logging.dart';

/// Flutter-specific facade over the core registration service.
class RegistrationService extends RegistrationServiceCore {
  factory RegistrationService() => _singleton;

  RegistrationService._internal({RegistrationApi? api})
      : _log = Logger('RegistrationService'),
        super(
          keyManager: LibMsgr().keyManager,
          secureStorage: LibMsgr().secureStorage,
          deviceInfoProvider: LibMsgr().deviceInfo,
          api: api,
        ) {
    _log.info('RegistrationService starting up');
  }

  final Logger _log;
  static final RegistrationService _singleton = RegistrationService._internal();

  String get deviceId => keyManager.deviceId;

  Future<AuthChallenge?> requestForSignInCodeEmail(String email) async {
    this.email = email;
    return requestChallenge(channel: 'email', identifier: email);
  }

  Future<AuthChallenge?> requestForSignInCodeMsisdn(String msisdn) async {
    this.msisdn = msisdn;
    return requestChallenge(channel: 'phone', identifier: msisdn);
  }

  Future<User?> submitEmailCodeForToken({
    required String challengeId,
    required String code,
    String? displayName,
  }) async {
    final session = await verifyCode(
      challengeId: challengeId,
      code: code,
      displayName: displayName ?? email,
    );
    return session != null ? _toUser(session) : null;
  }

  Future<User?> submitMsisdnCodeForToken({
    required String challengeId,
    required String code,
    String? displayName,
  }) async {
    final session = await verifyCode(
      challengeId: challengeId,
      code: code,
      displayName: displayName ?? msisdn,
    );
    return session != null ? _toUser(session) : null;
  }

  Future<List<Team>> listMyTeams(String accessToken) async {
    final teams = await listTeams(token: accessToken);
    return teams.map((e) => Team.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>?> selectTeamForToken({
    required String teamName,
    required String token,
  }) {
    return super.selectTeam(teamName: teamName, token: token);
  }

  Future<Profile?> createProfileForTeam({
    required String teamName,
    required String token,
    required String username,
    required String firstName,
    required String lastName,
  }) async {
    final result = await super.createProfile(
      teamName: teamName,
      token: token,
      username: username,
      firstName: firstName,
      lastName: lastName,
    );
    if (result == null) {
      return null;
    }
    return Profile.fromJson(result.data);
  }

  Future<Team?> createNewTeam(
    String teamName,
    String teamDesc,
    String token,
  ) async {
    final result = await super.createTeam(
      teamName: teamName,
      description: teamDesc,
      token: token,
    );
    if (result == null) {
      return null;
    }
    return Team.fromJson(result.team);
  }

  User _toUser(UserSession session) {
    final userId = session.userId ?? session.identifier;
    return User(
      id: userId,
      identifier: session.identifier,
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
  }
}

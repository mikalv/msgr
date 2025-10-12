import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/models/profile.dart';
import 'package:libmsgr/src/models/team.dart';
import 'package:libmsgr/src/models/user.dart';
import 'package:libmsgr/src/repositories/base.dart';
import 'package:libmsgr_core/libmsgr_core.dart';

class AuthRepository extends BaseRepository<User> {
  AuthRepository({required super.teamName}) : _registration = RegistrationService();

  final RegistrationService _registration;

  Future<AuthChallenge?> requestMsisdnCode(String msisdn) async {
    await _registration.maybeRegisterDevice();
    return _registration.requestForSignInCodeMsisdn(msisdn);
  }

  Future<AuthChallenge?> requestEmailCode(String email) async {
    await _registration.maybeRegisterDevice();
    return _registration.requestForSignInCodeEmail(email);
  }

  Future<User?> loginWithEmailAndCode({
    required String challengeId,
    required String code,
    String? displayName,
  }) async {
    return _registration.submitEmailCodeForToken(
      challengeId: challengeId,
      code: code,
      displayName: displayName,
    );
  }

  Future<User?> loginWithMsisdnAndCode({
    required String challengeId,
    required String code,
    String? displayName,
  }) async {
    return _registration.submitMsisdnCodeForToken(
      challengeId: challengeId,
      code: code,
      displayName: displayName,
    );
  }

  Future<List<Team>> listMyTeams(String accessToken) async {
    return _registration.listMyTeams(accessToken);
  }

  Future<Map<String, dynamic>?> selectTeam(String teamName, String token) {
    return _registration.selectTeamForToken(
      teamName: teamName,
      token: token,
    );
  }

  Future<Profile?> createProfile(
    String teamName,
    String token,
    String username,
    String firstName,
    String lastName,
  ) async {
    return _registration.createProfileForTeam(
      teamName: teamName,
      token: token,
      username: username,
      firstName: firstName,
      lastName: lastName,
    );
  }

  Future<Team?> createNewTeam(
    String teamName,
    String teamDesc,
    String token,
  ) async {
    return _registration.createNewTeam(teamName, teamDesc, token);
  }

  Future<RefreshSessionResponse?> refreshSession(String refreshToken) {
    return _registration.refreshSession(refreshToken: refreshToken);
  }
}

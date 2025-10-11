import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/registration_service.dart';
import 'package:libmsgr/src/repositories/base.dart';

/// This function takes a list of integers and returns a new list with each
/// integer incremented by one.
///
/// - Parameter numbers: A list of integers to be incremented.
/// - Returns: A new list of integers where each integer is incremented by one.
class AuthRepository extends BaseRepository<User> {
  AuthRepository({required super.teamName});

  Future<User?> getAuthenticatedUser() async {}
  Future<Device?> getDevice() async {}

  Future<bool> requestMsisdnCode(String msisdn) async {
    await RegistrationService().maybeRegisterDevice();
    return RegistrationService().requestForSignInCodeMsisdn(msisdn);
  }

  Future<bool> requestEmailCode(String email) async {
    await RegistrationService().maybeRegisterDevice();
    return RegistrationService().requestForSignInCodeEmail(email);
  }

  Future<User?> loginWithEmailAndCode(String email, String code) {
    return RegistrationService().submitEmailCodeForToken(email, code);
  }

  Future<User?> loginWithMsisdnAndCode(String msisdn, String code) {
    return RegistrationService().submitMsisdnCodeForToken(msisdn, code);
  }

  Future<List<Team>> listMyTeams(String accessToken) async {
    return RegistrationService().listMyTeams(accessToken);
  }

  Future<Map<String, dynamic>?> selectTeam(
      String teamName, String token) async {
    return RegistrationService().selectTeam(teamName, token);
  }

  Future<Profile?> createProfile(String teamName, String token, String username,
      String firstName, String lastName) async {
    return RegistrationService()
        .createProfile(teamName, token, username, firstName, lastName);
  }

  Future<Team?> createNewTeam(
      String teamName, String teamDesc, String token) async {
    return RegistrationService().createNewTeam(teamName, teamDesc, token);
  }
}

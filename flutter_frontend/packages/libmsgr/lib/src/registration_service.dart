import 'dart:convert';
import 'dart:io';

import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/server_resolver.dart';
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;

// HttpHeaders.authorizationHeader
// This is implemented as a singleton and not as a provider like services
// in this project would for the most be, I assume...
class RegistrationService {
  static final RegistrationService _singleton = RegistrationService._internal();
  final Logger _log = Logger('RegistrationService');

  final client = http.Client();
  late String deviceId;
  var mapDeviceInfo = {};
  String? msisdn;
  String? email;
  AuthChallenge? lastChallenge;

  factory RegistrationService() {
    return _singleton;
  }

  RegistrationService._internal() {
    _log.info('RegistrationService starting up');
    _setdeviceinfo();
  }

  maybeRegisterDevice() async {
    var isReg = await LibMsgr()
        .secureStorage
        .containsKey(kIsDeviceRegisteredWithServerNameStr);
    if (!isReg) {
      _log.info('Attempting to register device!');
      await registerDevice();
      await LibMsgr()
          .secureStorage
          .writeValue(kIsDeviceRegisteredWithServerNameStr, deviceId);
    } else {}
  }

  Future<bool> registerDevice() async {
    _log.finest('registerDevice triggered');
    var url = ServerResolver.getAuthServer('/api/v1/device/register');
    var keyData = await LibMsgr().keyManager.getDataForServer();
    deviceId = LibMsgr().keyManager.deviceId!;
    var srvData = jsonEncode({
      'from': deviceId,
      'payload': {
        'keyData': keyData,
        'deviceInfo': mapDeviceInfo,
      }
    });
    var hdrs = {
      'Content-Type': 'application/json; charset=UTF-8',
      'User-Agent': kUserAgentNameString
    };
    var response = await http.post(url, body: srvData, headers: hdrs);
    _log.finest('registerDevice Response status: ${response.statusCode}');
    _log.finest('registerDevice Response body: ${response.body}');
    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  Future<Profile?> createProfile(String teamName, String token, String username,
      String firstName, String lastName) async {
    _log.finest('createProfile triggered');
    var url = ServerResolver.getTeamServer(teamName, '/v1/api/profiles');

    var body = {
      'first_name': firstName,
      'last_name': lastName,
      'username': username
    };

    var hdrs = {
      'Content-Type': 'application/json; charset=UTF-8',
      'User-Agent': kUserAgentNameString,
      HttpHeaders.authorizationHeader: 'Bearer $token'
    };
    var response = await http.post(url, body: jsonEncode(body), headers: hdrs);
    _log.finest(
        'createProfile Response status: ${response.statusCode} url= $url');
    _log.finest('createProfile Response body: ${response.body}');
    if (response.statusCode == 200) {
      var message = jsonDecode(response.body);
      return Profile.fromJson(message);
    } else {
      return null;
    }
  }

  Future<Map<String, dynamic>?> selectTeam(
      String teamName, String token) async {
    _log.finest('selectTeam triggered');
    var url =
        ServerResolver.getMainServer('/public/v1/api/select/team/$teamName');

    var hdrs = {
      'Content-Type': 'application/json; charset=UTF-8',
      'User-Agent': kUserAgentNameString,
      HttpHeaders.authorizationHeader: 'Bearer $token'
    };
    var response = await http.post(url, headers: hdrs);
    _log.finest('selectTeam Response status: ${response.statusCode} url= $url');
    _log.finest('selectTeam Response body: ${response.body}');
    if (response.statusCode == 200) {
      var message = jsonDecode(response.body);
      if (message['status'] == 'ok') {
        return message;
      } else {
        return null;
      }
    } else {
      return null;
    }
  }

  Future<User?> submitEmailCodeForToken({
    required String challengeId,
    required String code,
    String? displayName,
  }) async {
    return _submitCodeForToken(
      challengeId: challengeId,
      code: code,
      displayName: displayName ?? email,
    );
  }

  Future<User?> submitMsisdnCodeForToken({
    required String challengeId,
    required String code,
    String? displayName,
  }) async {
    return _submitCodeForToken(
      challengeId: challengeId,
      code: code,
      displayName: displayName ?? msisdn,
    );
  }

  Future<User?> _submitCodeForToken({
    required String challengeId,
    required String code,
    String? displayName,
  }) async {
    _log.finest('submitCodeForToken triggered');
    deviceId = LibMsgr().keyManager.deviceId!;

    var url = ServerResolver.getAuthServer('/api/auth/verify');
    var hdrs = {
      'Content-Type': 'application/json; charset=UTF-8',
      'User-Agent': kUserAgentNameString
    };
    var body = jsonEncode({
      'challenge_id': challengeId,
      'code': code,
      if (displayName != null && displayName.isNotEmpty) 'display_name': displayName,
    });
    var response = await http.post(url, body: body, headers: hdrs);
    _log.finest('submitCodeForToken Response status: ${response.statusCode}');
    _log.finest('submitCodeForToken Response body: ${response.body}');
    if (response.statusCode == 200) {
      var message = jsonDecode(response.body) as Map<String, dynamic>;
      var account = message['account'] as Map<String, dynamic>;
      var identity = message['identity'] as Map<String, dynamic>;

      var identifier = account['email'] ?? account['phone_number'] ?? identity['kind'];
      return User(
        id: account['id'] as String?,
        identifier: identifier as String,
        accessToken: identity['id'] as String,
        refreshToken: identity['id'] as String,
      );
    }
    return null;
  }

  Future<AuthChallenge?> requestForSignInCodeEmail(String? inputEmail) async {
    deviceId = LibMsgr().keyManager.deviceId!;
    if (inputEmail == null || inputEmail.isEmpty) {
      _log.warning(
          'An attempt to call requestForSignInCode with no arguments!');
      return Future.value(null);
    }
    email = inputEmail;
    return _requestForSignInCode({
      'channel': 'email',
      'identifier': inputEmail,
      'device_id': deviceId,
    });
  }

  Future<AuthChallenge?> requestForSignInCodeMsisdn(String? number) async {
    deviceId = LibMsgr().keyManager.deviceId!;
    if (number == null || number.isEmpty) {
      _log.warning(
          'An attempt to call requestForSignInCode with no arguments!');
      return Future.value(null);
    }
    msisdn = number;
    return _requestForSignInCode({
      'channel': 'phone',
      'identifier': number,
      'device_id': deviceId,
    });
  }

  Future<AuthChallenge?> _requestForSignInCode(Map<String, dynamic> body) async {
    _log.finest('requestForSignInCode triggered (body: $body)');

    deviceId = LibMsgr().keyManager.deviceId!;

    var url = ServerResolver.getAuthServer('/api/auth/challenge');
    var hdrs = {
      'Content-Type': 'application/json; charset=UTF-8',
      'User-Agent': kUserAgentNameString
    };
    var response = await http.post(url, body: jsonEncode(body), headers: hdrs);
    _log.finest('requestForSignInCode Response status: ${response.statusCode}');
    _log.finest('requestForSignInCode Response body: ${response.body}');
    if (response.statusCode == 201) {
      var message = jsonDecode(response.body) as Map<String, dynamic>;
      lastChallenge = AuthChallenge.fromJson(message);
      return lastChallenge;
    }
    return null;
  }

  Future<User?> completeOidc({
    required String provider,
    required String subject,
    String? email,
    String? name,
  }) async {
    var url = ServerResolver.getAuthServer('/api/auth/oidc');
    var hdrs = {
      'Content-Type': 'application/json; charset=UTF-8',
      'User-Agent': kUserAgentNameString
    };
    var response = await http.post(
      url,
      headers: hdrs,
      body: jsonEncode({
        'provider': provider,
        'subject': subject,
        if (email != null) 'email': email,
        if (name != null) 'name': name,
      }),
    );

    if (response.statusCode == 200) {
      var message = jsonDecode(response.body) as Map<String, dynamic>;
      var account = message['account'] as Map<String, dynamic>;
      var identity = message['identity'] as Map<String, dynamic>;

      var identifier = account['email'] ?? account['phone_number'] ?? identity['kind'];
      return User(
        id: account['id'] as String?,
        identifier: identifier as String,
        accessToken: identity['id'] as String,
        refreshToken: identity['id'] as String,
      );
    }
    return null;
  }

  Future<Team?> createNewTeam(
      String teamName, String teamDesc, String token) async {
    _log.finest('createNewTeam triggered');

    var url = ServerResolver.getMainServer('/public/v1/api/teams');
    Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
    var body = {
      'team_name': teamName,
      'description': teamDesc,
      'uid': decodedToken['sub']
    };
    var hdrs = {
      'Content-Type': 'application/json; charset=UTF-8',
      'User-Agent': kUserAgentNameString,
      HttpHeaders.authorizationHeader: 'Bearer $token'
    };
    var response = await http.post(url, body: jsonEncode(body), headers: hdrs);
    _log.finest(
        'createNewTeam Response status: ${response.statusCode} url= $url');
    _log.finest('createNewTeam Response body: ${response.body}');
    if (response.statusCode == 200) {
      var message = jsonDecode(response.body);
      if (message['status'] == 'ok') {
        return Team.fromJson(message['team']);
      } else {
        return null;
      }
    } else {
      return null;
    }
  }

  Future<List<Team>> listMyTeams(token) async {
    _log.finest('listMyTeams triggered');

    var url = ServerResolver.getMainServer('/public/v1/api/teams');
    var hdrs = {
      'Content-Type': 'application/json; charset=UTF-8',
      'User-Agent': kUserAgentNameString,
      HttpHeaders.authorizationHeader: 'Bearer $token'
    };
    var response = await http.get(url, headers: hdrs);
    _log.finest(
        'listMyTeams Response status: ${response.statusCode} url= $url');
    _log.finest('listMyTeams Response body: ${response.body}');
    if (response.statusCode == 200) {
      var message = jsonDecode(response.body);
      if (message['status'] == 'ok') {
        return message['teams'].map<Team>((obj) => Team.fromJson(obj)).toList()
            as List<Team>;
      } else {
        return [];
      }
    } else {
      return [];
    }
  }

  _setdeviceinfo() async {
    _log.finer('Device Info: $mapDeviceInfo');
  }
}

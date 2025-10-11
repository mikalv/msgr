import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:libmsgr/libmsgr.dart';
import 'package:logging/logging.dart';

import 'memory_adapters.dart';

/// Holds all state required to interact with the libmsgr APIs from the CLI.
class CliEnvironment {
  CliEnvironment({
    required this.lib,
    required this.secureStorage,
    required this.sharedPreferences,
    required this.deviceInfo,
    required this.registration,
  });

  final LibMsgr lib;
  final MemorySecureStorage secureStorage;
  final MemorySharedPreferences sharedPreferences;
  final FakeDeviceInfo deviceInfo;
  final RegistrationService registration;

  static Future<CliEnvironment> bootstrap({String? deviceId}) async {
    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((event) {
      stderr.writeln('[${event.level.name}] ${event.loggerName}: ${event.message}');
    });

    final secureStorage = MemorySecureStorage();
    final sharedPreferences = MemorySharedPreferences();
    final lib = LibMsgr();
    lib.secureStorage = secureStorage;
    lib.sharedPreferences = sharedPreferences;

    final resolvedDeviceId =
        deviceId ?? 'device-${DateTime.now().millisecondsSinceEpoch}';
    final deviceInfo = FakeDeviceInfo(resolvedDeviceId);
    lib.deviceInfoInstance = deviceInfo;

    await lib.bootstrapLibrary();

    final registration = RegistrationService();
    final appInfo = await deviceInfo.appInfo();
    registration.updateCachedContext(
      deviceInfo: deviceInfo.info,
      appInfo: appInfo,
    );
    await registration.maybeRegisterDevice(
      deviceInfo: deviceInfo.info,
      appInfo: appInfo,
    );

    return CliEnvironment(
      lib: lib,
      secureStorage: secureStorage,
      sharedPreferences: sharedPreferences,
      deviceInfo: deviceInfo,
      registration: registration,
    );
  }
}

class IntegrationFlowResult {
  IntegrationFlowResult({
    required this.email,
    required this.userId,
    required this.teamId,
    required this.teamName,
    required this.profileId,
    required this.teamAccessToken,
    required this.teamHost,
    required this.teamsCount,
  });

  final String email;
  final String userId;
  final String teamId;
  final String teamName;
  final String profileId;
  final String teamAccessToken;
  final String teamHost;
  final int teamsCount;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'email': email,
      'userId': userId,
      'teamId': teamId,
      'teamName': teamName,
      'profileId': profileId,
      'teamAccessToken': teamAccessToken,
      'teamHost': teamHost,
      'teamsCount': teamsCount,
    };
  }
}

/// Executes the integration happy-path against the authentication backend.
Future<IntegrationFlowResult> runIntegrationFlow({
  String? email,
  String? teamName,
  String? username,
  String? displayName,
}) async {
  final environment = await CliEnvironment.bootstrap();

  final resolvedEmail =
      email ?? 'integration+${DateTime.now().millisecondsSinceEpoch}@example.com';
  final resolvedTeamName = teamName ??
      'integration${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
  final resolvedUsername =
      username ?? 'integration_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
  final resolvedDisplayName = displayName ?? 'Integration User';

  final registration = environment.registration;
  final challenge =
      await registration.requestForSignInCodeEmail(resolvedEmail);
  if (challenge == null || challenge.debugCode == null) {
    throw StateError('Failed to obtain OTP challenge for $resolvedEmail');
  }

  final user = await registration.submitEmailCodeForToken(
    challengeId: challenge.id,
    code: challenge.debugCode!,
    displayName: resolvedDisplayName,
  );
  if (user == null) {
    throw StateError('Failed to exchange OTP for user session');
  }

  final authRepo = environment.lib.authRepository as AuthRepository;
  final team = await authRepo.createNewTeam(
    resolvedTeamName,
    'Integration test team created via CLI',
    user.accessToken,
  );
  if (team == null) {
    throw StateError('Failed to create team $resolvedTeamName');
  }

  final selection = await authRepo.selectTeam(team.name, user.accessToken);
  if (selection == null) {
    throw StateError('Failed to select team ${team.name}');
  }

  final teamAccessToken = selection['teamAccessToken'] as String?;
  if (teamAccessToken == null || teamAccessToken.isEmpty) {
    throw StateError('Team access token missing in selection response');
  }

  String? profileId =
      (selection['profile'] as Map<String, dynamic>?)?['id'] as String?;
  if (profileId == null) {
    final profile = await authRepo.createProfile(
      team.name,
      teamAccessToken,
      resolvedUsername,
      resolvedDisplayName.split(' ').first,
      resolvedDisplayName.split(' ').last,
    );
    if (profile == null || profile.id == null) {
      throw StateError('Failed to create profile for team ${team.name}');
    }
    profileId = profile.id;
  }

  final teams = await authRepo.listMyTeams(user.accessToken);
  final host = '${team.name}.teams.7f000001.nip.io:4080';

  return IntegrationFlowResult(
    email: resolvedEmail,
    userId: user.uid,
    teamId: team.id,
    teamName: team.name,
    profileId: profileId,
    teamAccessToken: teamAccessToken,
    teamHost: host,
    teamsCount: teams.length,
  );
}

String prettyPrintJson(Map<String, dynamic> jsonObject) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(jsonObject);
}

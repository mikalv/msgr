import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:libmsgr_core/libmsgr_core.dart';

import '../cli_environment.dart';

class IntegrationFlowResult {
  IntegrationFlowResult({
    required this.email,
    required this.user,
    required this.team,
    required this.profileId,
    required this.teamAccessToken,
    required this.teamHost,
    required this.teamsCount,
  });

  final String email;
  final UserSession user;
  final Map<String, dynamic> team;
  final String profileId;
  final String teamAccessToken;
  final String teamHost;
  final int teamsCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'email': email,
        'userId': user.userId,
        'identifier': user.identifier,
        'teamId': team['id'],
        'teamName': team['name'],
        'profileId': profileId,
        'teamAccessToken': teamAccessToken,
        'teamHost': teamHost,
        'teamsCount': teamsCount,
      };
}

class IntegrationFlowCommand extends Command<void> {
  IntegrationFlowCommand() {
    configureIntegrationCommandArgs(argParser);
  }

  @override
  String get description =>
      'Register device, complete OTP flow and create a team via libmsgr_core.';

  @override
  String get name => 'integration-flow';

  @override
  void addCommand(Command<void> command) {}

  @override
  Future<void> run() async {
    final options = IntegrationFlowOptions.fromArgResults(argResults);
    final environment = await CliEnvironment.bootstrap(stateDir: options.stateDir);

    final resolvedEmail = options.email ??
        'integration+${DateTime.now().millisecondsSinceEpoch}@example.com';
    final resolvedTeamName = options.teamName ??
        'integration${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    final resolvedUsername = options.username ??
        'integration_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    final resolvedDisplayName = options.displayName ?? 'Integration User';

    final registration = environment.registration;

    // Request OTP challenge (email).
    final challenge = await registration.requestChallenge(
      channel: 'email',
      identifier: resolvedEmail,
    );
    if (challenge == null || challenge.debugCode == null) {
      throw StateError('Failed to obtain OTP challenge for $resolvedEmail');
    }

    final session = await registration.verifyCode(
      challengeId: challenge.id,
      code: challenge.debugCode!,
      displayName: resolvedDisplayName,
    );
    if (session == null) {
      throw StateError('Failed to exchange OTP for user session');
    }

    // Create team.
    final teamResult = await registration.createTeam(
      teamName: resolvedTeamName,
      description: 'Integration test team created via CLI',
      token: session.accessToken,
    );
    if (teamResult == null) {
      throw StateError('Failed to create team $resolvedTeamName');
    }

    final selection = await registration.selectTeam(
      teamName: resolvedTeamName,
      token: session.accessToken,
    );
    if (selection == null) {
      throw StateError('Failed to select team ${teamResult.team['name']}');
    }

    final teamAccessToken = selection['teamAccessToken'] as String?;
    if (teamAccessToken == null || teamAccessToken.isEmpty) {
      throw StateError('Team access token missing in selection response');
    }

    String? profileId =
        (selection['profile'] as Map<String, dynamic>?)?['id'] as String?;
    if (profileId == null) {
      final createProfileResponse = await registration.createProfile(
        teamName: resolvedTeamName,
        token: teamAccessToken,
        username: resolvedUsername,
        firstName: resolvedDisplayName.split(' ').first,
        lastName: resolvedDisplayName.split(' ').last,
      );
      if (createProfileResponse == null || createProfileResponse.id == null) {
        throw StateError('Failed to create profile for team ${teamResult.team['name']}');
      }
      profileId = createProfileResponse.id;
    }

    final teams = await registration.listTeams(token: session.accessToken);
    final host = MsgrConstants.localDevelopment
        ? '${teamResult.team['name']}.${MsgrHosts.localApiServer}'
        : '${teamResult.team['name']}.${MsgrHosts.apiServer}';

    final resolvedProfileId = profileId;
    if (resolvedProfileId == null) {
      throw StateError('Unable to resolve profile id for ${teamResult.team['name']}');
    }

    final result = IntegrationFlowResult(
      email: resolvedEmail,
      user: session,
      team: teamResult.team,
      profileId: resolvedProfileId,
      teamAccessToken: teamAccessToken,
      teamHost: host,
      teamsCount: teams.length,
    );

    if (options.jsonOutput) {
      stdout.writeln(jsonEncode(result.toJson()));
    } else {
      stdout.writeln('Integration flow completed successfully:\n');
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(result.toJson()));
    }
  }
}

class IntegrationFlowOptions {
  IntegrationFlowOptions({
    this.email,
    this.teamName,
    this.username,
    this.displayName,
    required this.jsonOutput,
    this.stateDir,
  });

  final String? email;
  final String? teamName;
  final String? username;
  final String? displayName;
  final bool jsonOutput;
  final Directory? stateDir;

  static IntegrationFlowOptions fromArgResults(ArgResults? results) {
    final stateDirPath = results?['state-dir'] as String?;
    return IntegrationFlowOptions(
      email: results?['email'] as String?,
      teamName: results?['team-name'] as String?,
      username: results?['username'] as String?,
      displayName: results?['display-name'] as String?,
      jsonOutput: results?['json'] as bool? ?? false,
      stateDir: stateDirPath != null ? Directory(stateDirPath) : null,
    );
  }
}

void configureIntegrationCommandArgs(ArgParser parser) {
  parser
    ..addOption(
      'email',
      help: 'Email address used during the flow (defaults to generated value).',
    )
    ..addOption(
      'team-name',
      help: 'Team name to create (defaults to a generated value).',
    )
    ..addOption(
      'username',
      help: 'Username to create when no profile exists.',
    )
    ..addOption(
      'display-name',
      help: 'Display name used for the created account.',
    )
    ..addOption(
      'state-dir',
      help: 'Directory to store CLI persistent state (defaults to ~/.msgr_cli).',
    )
    ..addFlag(
      'json',
      abbr: 'j',
      defaultsTo: false,
      help: 'Emit machine readable JSON instead of pretty text.',
    );
}

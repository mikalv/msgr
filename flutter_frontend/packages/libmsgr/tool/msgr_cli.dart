import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import 'src/cli_flow.dart';

class IntegrationFlowCommand extends Command<void> {
  IntegrationFlowCommand() {
    argParser
      ..addOption(
        'email',
        help: 'Email address to use during the flow (defaults to a random value).',
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
      ..addFlag(
        'json',
        abbr: 'j',
        defaultsTo: false,
        help: 'Emit JSON instead of pretty text.',
      );
  }

  @override
  String get description =>
      'Register a device, request an email OTP and create a team using libmsgr.';

  @override
  String get name => 'integration-flow';

  @override
  Future<void> run() async {
    final result = await runIntegrationFlow(
      email: argResults?['email'] as String?,
      teamName: argResults?['team-name'] as String?,
      username: argResults?['username'] as String?,
      displayName: argResults?['display-name'] as String?,
    );

    final jsonMap = result.toJson();
    if (argResults?.flag('json') ?? false) {
      stdout.writeln(jsonEncode(jsonMap));
      return;
    }

    stdout.writeln('Integration flow completed successfully:\n');
    stdout.writeln(prettyPrintJson(jsonMap));
  }
}

Future<void> main(List<String> args) async {
  final runner = CommandRunner<void>(
    'msgr',
    'CLI entry point for exercising libmsgr flows.',
  )
    ..addCommand(IntegrationFlowCommand());

  try {
    await runner.run(args);
  } on UsageException catch (error) {
    stderr.writeln(error);
    exitCode = 64; // EX_USAGE
  } catch (error, stackTrace) {
    stderr.writeln('CLI failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

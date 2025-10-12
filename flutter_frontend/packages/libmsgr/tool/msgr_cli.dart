import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:libmsgr_cli/libmsgr_cli.dart';

/// Legacy entrypoint forwarding to the new libmsgr_cli package.
Future<void> main(List<String> args) async {
  final runner = MsgrCliRunner();
  try {
    await runner.run(args);
  } on UsageException catch (error) {
    stderr.writeln(error);
    exitCode = 64;
  } catch (error, stackTrace) {
    stderr.writeln('CLI failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

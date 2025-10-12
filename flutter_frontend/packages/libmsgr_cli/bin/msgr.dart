import 'dart:io';

import 'package:libmsgr_cli/libmsgr_cli.dart';

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

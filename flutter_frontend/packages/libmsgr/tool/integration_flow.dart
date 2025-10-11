import 'dart:convert';
import 'dart:io';

import 'src/cli_flow.dart';

Future<void> main(List<String> args) async {
  try {
    final result = await runIntegrationFlow();
    stdout.writeln(jsonEncode(result.toJson()));
  } catch (error, stackTrace) {
    stderr.writeln('Integration flow failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

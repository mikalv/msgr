import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:libmsgr_cli/libmsgr_cli.dart';
import 'package:test/test.dart';

void main() {
  group('MsgrCliRunner', () {
    test('registers integration-flow command', () {
      final runner = MsgrCliRunner();
      expect(runner.commands.keys, contains('integration-flow'));
    });

    test('throws UsageException for unknown command', () async {
      final runner = MsgrCliRunner();
      expect(
        () async => runner.run(['does-not-exist']),
        throwsA(isA<UsageException>()),
      );
    });
  });

  group('IntegrationFlowOptions', () {
    test('parses state-dir option into Directory', () {
      final parser = ArgParser();
      configureIntegrationCommandArgs(parser);
      final results = parser.parse([
        '--state-dir',
        '/tmp/msgr-cli',
      ]);

      final options = IntegrationFlowOptions.fromArgResults(results);
      expect(options.stateDir, isNotNull);
      expect(options.stateDir!.path, '/tmp/msgr-cli');
    });
  });
}

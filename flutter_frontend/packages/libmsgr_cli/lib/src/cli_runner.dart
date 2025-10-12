import 'package:args/command_runner.dart';

import 'commands/integration_flow_command.dart';

class MsgrCliRunner extends CommandRunner<void> {
  MsgrCliRunner()
      : super(
          'msgr',
          'Command line tooling for exercising msgr backend flows.',
        ) {
    addCommand(IntegrationFlowCommand());
  }
}

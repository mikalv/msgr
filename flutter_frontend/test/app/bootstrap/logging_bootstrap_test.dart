import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:messngr/app/bootstrap/logging_bootstrap.dart';

void main() {
  setUp(() {
    Logger.root.level = Level.INFO;
  });

  test('bootstrapLogging sets the provided log level', () {
    bootstrapLogging(level: Level.SEVERE, createLogClient: () => null);

    expect(Logger.root.level, Level.SEVERE);
  });
}

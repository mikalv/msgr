import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/config/logging_environment.dart';

void main() {
  final environment = LoggingEnvironment.instance;

  setUp(() {
    environment.clearOverride();
  });

  test('builds ingest URI from overrides', () {
    environment.override(
      endpoint: 'http://observability.local',
      org: 'custom-org',
      stream: 'mobile',
      dataset: '_json',
    );

    expect(
      environment.ingestUri.toString(),
      equals('http://observability.local/api/custom-org/logs/mobile/_json'),
    );
  });

  test('computes basic authorization header', () {
    environment.override(
      enabled: true,
      username: 'user@example.com',
      password: 'secret',
    );

    expect(
      environment.authorizationHeader,
      equals({'Authorization': 'Basic dXNlckBleGFtcGxlLmNvbTpzZWNyZXQ='}),
    );
  });
}

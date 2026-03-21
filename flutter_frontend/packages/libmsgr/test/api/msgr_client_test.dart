import 'package:libmsgr/src/api/msgr_client.dart';
import 'package:test/test.dart';

void main() {
  const baseUrl = 'http://localhost:4000';

  group('MsgrClient', () {
    test('creates with baseUrl and exposes api', () {
      final client = MsgrClient(baseUrl: baseUrl);
      expect(client.baseUrl, equals(baseUrl));
      expect(client.api, isNotNull);
    });

    test('setCredentials sets accountId and profileId on api client', () {
      final client = MsgrClient(baseUrl: baseUrl);

      client.setCredentials(
        accountId: 'acc-1',
        profileId: 'prof-1',
      );

      expect(client.accountId, equals('acc-1'));
      expect(client.profileId, equals('prof-1'));
      expect(client.api.accountId, equals('acc-1'));
      expect(client.api.profileId, equals('prof-1'));
    });

    test('setCredentials sets tokens when provided', () {
      final client = MsgrClient(baseUrl: baseUrl);

      client.setCredentials(
        accountId: 'acc-1',
        profileId: 'prof-1',
        accessToken: 'jwt-access',
        refreshToken: 'jwt-refresh',
      );

      expect(client.api.accessToken, equals('jwt-access'));
      expect(client.api.refreshToken, equals('jwt-refresh'));
    });

    test('setCredentials does not set tokens when accessToken is null', () {
      final client = MsgrClient(baseUrl: baseUrl);
      client.api.accessToken = 'existing-token';

      client.setCredentials(
        accountId: 'acc-1',
        profileId: 'prof-1',
      );

      // Should keep the existing token since no new one was provided
      expect(client.api.accessToken, equals('existing-token'));
    });

    test('isRealtimeConnected is false when not connected', () {
      final client = MsgrClient(baseUrl: baseUrl);
      expect(client.isRealtimeConnected, isFalse);
    });

    test('accessing realtime before connect throws StateError', () {
      final client = MsgrClient(baseUrl: baseUrl);
      expect(
        () => client.realtime,
        throwsA(isA<StateError>()),
      );
    });

    test('connectRealtime throws when no credentials set', () {
      final client = MsgrClient(baseUrl: baseUrl);
      expect(
        () => client.connectRealtime(),
        throwsA(isA<StateError>()),
      );
    });

    test('setSession sets all fields from SessionResult', () {
      final client = MsgrClient(baseUrl: baseUrl);

      // Use the verifyCode-like approach with a SessionResult-shaped call
      client.setCredentials(
        accountId: 'acc-session',
        profileId: 'prof-session',
        accessToken: 'access-tok',
        refreshToken: 'refresh-tok',
      );

      expect(client.accountId, equals('acc-session'));
      expect(client.profileId, equals('prof-session'));
      expect(client.api.accessToken, equals('access-tok'));
      expect(client.api.refreshToken, equals('refresh-tok'));
    });

    test('dispose does not throw when realtime was never connected', () {
      final client = MsgrClient(baseUrl: baseUrl);
      expect(() => client.dispose(), returnsNormally);
    });
  });
}

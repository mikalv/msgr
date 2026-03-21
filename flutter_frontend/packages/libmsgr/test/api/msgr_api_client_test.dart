import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:libmsgr/src/api/models.dart';
import 'package:libmsgr/src/api/msgr_api_client.dart';
import 'package:test/test.dart';

void main() {
  const baseUrl = 'http://localhost:4000';

  /// Helper: build a [MsgrApiClient] backed by [MockClient].
  MsgrApiClient buildClient(
    MockClientHandler handler, {
    String? accountId,
    String? profileId,
    String? accessToken,
  }) {
    final client = MsgrApiClient(
      baseUrl: baseUrl,
      accountId: accountId,
      profileId: profileId,
      httpClient: MockClient(handler),
    );
    if (accessToken != null) client.accessToken = accessToken;
    return client;
  }

  // ---------------------------------------------------------------------------
  // Headers
  // ---------------------------------------------------------------------------

  group('headers', () {
    test('includes Bearer token when accessToken is set', () async {
      String? capturedAuth;

      final client = buildClient(
        (request) async {
          capturedAuth = request.headers['Authorization'];
          return http.Response('[]', 200);
        },
        accessToken: 'my-jwt-token',
      );

      await client.getTeams();
      expect(capturedAuth, equals('Bearer my-jwt-token'));
    });

    test('falls back to X-headers when no accessToken', () async {
      String? capturedAccountId;
      String? capturedProfileId;
      String? capturedAuth;

      final client = buildClient(
        (request) async {
          capturedAuth = request.headers['Authorization'];
          capturedAccountId = request.headers['X-Account-Id'];
          capturedProfileId = request.headers['X-Profile-Id'];
          return http.Response('[]', 200);
        },
        accountId: 'acc-1',
        profileId: 'prof-1',
      );

      await client.getTeams();
      expect(capturedAuth, isNull);
      expect(capturedAccountId, equals('acc-1'));
      expect(capturedProfileId, equals('prof-1'));
    });

    test('always includes Content-Type and Accept JSON headers', () async {
      late Map<String, String> capturedHeaders;

      final client = buildClient((request) async {
        capturedHeaders = request.headers;
        return http.Response('[]', 200);
      });

      await client.getTeams();
      expect(capturedHeaders['Content-Type'], equals('application/json'));
      expect(capturedHeaders['Accept'], equals('application/json'));
    });
  });

  // ---------------------------------------------------------------------------
  // Auth: requestChallenge
  // ---------------------------------------------------------------------------

  group('requestChallenge', () {
    test('posts correct URL and body, parses response', () async {
      late Uri capturedUri;
      late String capturedBody;

      final client = buildClient((request) async {
        capturedUri = request.url;
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            'id': 'chal-123',
            'channel': 'email',
            'debug_code': '999999',
            'target_hint': 'u***@example.com',
          }),
          200,
        );
      });

      final result =
          await client.requestChallenge('user@example.com', channel: 'email');

      expect(capturedUri.path, equals('/api/v1/auth/challenge'));
      final body = jsonDecode(capturedBody) as Map<String, dynamic>;
      expect(body['identifier'], equals('user@example.com'));
      expect(body['channel'], equals('email'));

      expect(result.id, equals('chal-123'));
      expect(result.channel, equals('email'));
      expect(result.debugCode, equals('999999'));
      expect(result.targetHint, equals('u***@example.com'));
    });

    test('throws MsgrApiException on failure', () async {
      final client = buildClient(
        (request) async => http.Response('Bad request', 400),
      );

      expect(
        () => client.requestChallenge('bad'),
        throwsA(isA<MsgrApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)),
      );
    });

    test('throws when response has no challenge id', () async {
      final client = buildClient(
        (request) async =>
            http.Response(jsonEncode({'id': ''}), 200),
      );

      expect(
        () => client.requestChallenge('user@example.com'),
        throwsA(isA<MsgrApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Auth: verifyCode
  // ---------------------------------------------------------------------------

  group('verifyCode', () {
    test('posts correct URL, parses account/profile/tokens', () async {
      late Uri capturedUri;
      late String capturedBody;

      final client = buildClient((request) async {
        capturedUri = request.url;
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            'account': {
              'id': 'acc-1',
              'email': 'u@example.com',
              'display_name': 'Alice',
              'profiles': [
                {'id': 'prof-1', 'display_name': 'Alice P'}
              ],
            },
            'profile_id': 'prof-1',
            'access_token': 'jwt-access',
            'refresh_token': 'jwt-refresh',
          }),
          200,
        );
      });

      final result = await client.verifyCode('chal-123', '999999');

      expect(capturedUri.path, equals('/api/v1/auth/verify'));
      final body = jsonDecode(capturedBody) as Map<String, dynamic>;
      expect(body['challenge_id'], equals('chal-123'));
      expect(body['code'], equals('999999'));

      expect(result.accountId, equals('acc-1'));
      expect(result.profileId, equals('prof-1'));
      expect(result.email, equals('u@example.com'));
      expect(result.displayName, equals('Alice'));
      expect(result.accessToken, equals('jwt-access'));
      expect(result.refreshToken, equals('jwt-refresh'));

      // Should auto-set tokens on the client
      expect(client.accessToken, equals('jwt-access'));
      expect(client.refreshToken, equals('jwt-refresh'));
    });

    test('extracts profile_id from profiles list when not top-level', () async {
      final client = buildClient((request) async {
        return http.Response(
          jsonEncode({
            'account': {
              'id': 'acc-2',
              'profiles': [
                {'id': 'prof-from-list'}
              ],
            },
          }),
          200,
        );
      });

      final result = await client.verifyCode('chal', '000');
      expect(result.profileId, equals('prof-from-list'));
    });

    test('throws when no account id in response', () async {
      final client = buildClient(
        (request) async =>
            http.Response(jsonEncode({'account': {}}), 200),
      );

      expect(
        () => client.verifyCode('chal', '000'),
        throwsA(isA<MsgrApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('throws on non-2xx status', () async {
      final client = buildClient(
        (request) async => http.Response('Unauthorized', 401),
      );

      expect(
        () => client.verifyCode('chal', '000'),
        throwsA(isA<MsgrApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Teams
  // ---------------------------------------------------------------------------

  group('getTeams', () {
    test('unwraps {data: [...]} response', () async {
      final client = buildClient((request) async {
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 't1', 'name': 'Team 1'},
              {'id': 't2', 'name': 'Team 2'},
            ]
          }),
          200,
        );
      });

      final teams = await client.getTeams();
      expect(teams, hasLength(2));
      expect(teams[0]['id'], equals('t1'));
    });

    test('handles bare list response', () async {
      final client = buildClient((request) async {
        return http.Response(
          jsonEncode([
            {'id': 't1', 'name': 'Team 1'}
          ]),
          200,
        );
      });

      final teams = await client.getTeams();
      expect(teams, hasLength(1));
    });
  });

  group('createTeam', () {
    test('sends correct body and parses response', () async {
      late String capturedBody;

      final client = buildClient((request) async {
        capturedBody = request.body;
        return http.Response(
          jsonEncode({'id': 'new-team', 'name': 'My Team', 'slug': 'my-team'}),
          201,
        );
      });

      final result =
          await client.createTeam('My Team', 'my-team', description: 'desc');

      final body = jsonDecode(capturedBody) as Map<String, dynamic>;
      expect(body['name'], equals('My Team'));
      expect(body['slug'], equals('my-team'));
      expect(body['description'], equals('desc'));
      expect(result['id'], equals('new-team'));
    });
  });

  // ---------------------------------------------------------------------------
  // Channels
  // ---------------------------------------------------------------------------

  group('getChannels', () {
    test('unwraps data array', () async {
      late Uri capturedUri;

      final client = buildClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'ch1', 'name': 'general'}
            ]
          }),
          200,
        );
      });

      final channels = await client.getChannels('my-team');
      expect(capturedUri.path, equals('/api/teams/my-team/channels'));
      expect(channels, hasLength(1));
      expect(channels[0]['name'], equals('general'));
    });

    test('returns empty list on unexpected format', () async {
      final client = buildClient(
        (request) async => http.Response(jsonEncode({'status': 'ok'}), 200),
      );

      final channels = await client.getChannels('my-team');
      expect(channels, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  group('sendMessage', () {
    test('sends content as {"text": "..."} map', () async {
      late String capturedBody;
      late Uri capturedUri;

      final client = buildClient((request) async {
        capturedBody = request.body;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({'id': 'msg-1', 'content': {'text': 'Hello'}}),
          201,
        );
      });

      await client.sendMessage('team-1', 'ch-1', 'Hello');

      expect(capturedUri.path,
          equals('/api/teams/team-1/channels/ch-1/messages'));
      final body = jsonDecode(capturedBody) as Map<String, dynamic>;
      expect(body['content'], equals({'text': 'Hello'}));
    });

    test('includes media_refs when provided', () async {
      late String capturedBody;

      final client = buildClient((request) async {
        capturedBody = request.body;
        return http.Response(jsonEncode({'id': 'msg-1'}), 201);
      });

      await client.sendMessage('t', 'c', 'hi', mediaRefs: ['ref1', 'ref2']);

      final body = jsonDecode(capturedBody) as Map<String, dynamic>;
      expect(body['media_refs'], equals(['ref1', 'ref2']));
    });
  });

  group('getMessages', () {
    test('sends pagination params', () async {
      late Uri capturedUri;

      final client = buildClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode([]), 200);
      });

      await client.getMessages('t', 'ch', limit: 25, before: 'cursor-abc');

      expect(capturedUri.queryParameters['limit'], equals('25'));
      expect(capturedUri.queryParameters['before'], equals('cursor-abc'));
    });

    test('defaults limit to 50', () async {
      late Uri capturedUri;

      final client = buildClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode([]), 200);
      });

      await client.getMessages('t', 'ch');
      expect(capturedUri.queryParameters['limit'], equals('50'));
      expect(capturedUri.queryParameters.containsKey('before'), isFalse);
    });

    test('unwraps data array', () async {
      final client = buildClient((request) async {
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'm1', 'content': {'text': 'hi'}}
            ]
          }),
          200,
        );
      });

      final messages = await client.getMessages('t', 'ch');
      expect(messages, hasLength(1));
      expect(messages[0]['id'], equals('m1'));
    });
  });

  // ---------------------------------------------------------------------------
  // Reactions
  // ---------------------------------------------------------------------------

  group('toggleReaction', () {
    test('posts to correct URL with message_id', () async {
      late Uri capturedUri;
      late String capturedBody;

      final client = buildClient((request) async {
        capturedUri = request.url;
        capturedBody = request.body;
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      await client.toggleReaction('t', 'ch', 'msg-42', ':+1:');

      expect(capturedUri.path,
          equals('/api/teams/t/channels/ch/messages/msg-42/reactions'));
      final body = jsonDecode(capturedBody) as Map<String, dynamic>;
      expect(body['emoji'], equals(':+1:'));
    });
  });

  // ---------------------------------------------------------------------------
  // Profiles
  // ---------------------------------------------------------------------------

  group('getProfiles', () {
    test('unwraps data array', () async {
      late Uri capturedUri;

      final client = buildClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'p1', 'display_name': 'Alice'}
            ]
          }),
          200,
        );
      });

      final profiles = await client.getProfiles('my-team');
      expect(capturedUri.path, equals('/api/teams/my-team/profiles'));
      expect(profiles, hasLength(1));
      expect(profiles[0]['display_name'], equals('Alice'));
    });

    test('handles bare list', () async {
      final client = buildClient((request) async {
        return http.Response(
          jsonEncode([
            {'id': 'p1'}
          ]),
          200,
        );
      });

      final profiles = await client.getProfiles('t');
      expect(profiles, hasLength(1));
    });
  });

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  group('getSettings', () {
    test('calls correct endpoint', () async {
      late Uri capturedUri;

      final client = buildClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({'theme': 'dark', 'notifications': true}),
          200,
        );
      });

      final settings = await client.getSettings();
      expect(capturedUri.path, equals('/api/settings'));
      expect(settings['theme'], equals('dark'));
    });
  });

  group('updateSettings', () {
    test('sends PUT to correct endpoint with body', () async {
      late Uri capturedUri;
      late String capturedMethod;
      late String capturedBody;

      final client = buildClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        capturedBody = request.body;
        return http.Response(jsonEncode({'theme': 'light'}), 200);
      });

      await client.updateSettings({'theme': 'light'});

      expect(capturedUri.path, equals('/api/settings'));
      expect(capturedMethod, equals('PUT'));
      final body = jsonDecode(capturedBody) as Map<String, dynamic>;
      expect(body['theme'], equals('light'));
    });
  });

  // ---------------------------------------------------------------------------
  // Auto-refresh on 401
  // ---------------------------------------------------------------------------

  group('auto-refresh on 401', () {
    test('refreshes token and retries request on 401', () async {
      var callCount = 0;

      final client = MsgrApiClient(
        baseUrl: baseUrl,
        httpClient: MockClient((request) async {
          // Refresh endpoint
          if (request.url.path == '/api/v1/auth/refresh') {
            return http.Response(
              jsonEncode({'access_token': 'new-token'}),
              200,
            );
          }

          callCount++;
          if (callCount == 1) {
            // First call returns 401
            return http.Response('Unauthorized', 401);
          }
          // Retry should succeed
          return http.Response(jsonEncode({'theme': 'dark'}), 200);
        }),
      );

      client.accessToken = 'old-token';
      client.refreshToken = 'refresh-tok';

      final result = await client.getSettings();
      expect(result['theme'], equals('dark'));
      expect(client.accessToken, equals('new-token'));
      expect(callCount, equals(2)); // original + retry
    });

    test('calls onTokensRefreshed callback', () async {
      String? refreshedToken;

      final client = MsgrApiClient(
        baseUrl: baseUrl,
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/v1/auth/refresh') {
            return http.Response(
              jsonEncode({'access_token': 'fresh-token'}),
              200,
            );
          }
          if (request.headers['Authorization'] == 'Bearer fresh-token') {
            return http.Response(jsonEncode({}), 200);
          }
          return http.Response('Unauthorized', 401);
        }),
      );

      client.accessToken = 'expired';
      client.refreshToken = 'refresh-tok';
      client.onTokensRefreshed = (access, refresh) {
        refreshedToken = access;
      };

      await client.getSettings();
      expect(refreshedToken, equals('fresh-token'));
    });

    test('calls onAuthFailure when refresh fails', () async {
      var authFailed = false;

      final client = MsgrApiClient(
        baseUrl: baseUrl,
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/v1/auth/refresh') {
            return http.Response('Invalid refresh token', 401);
          }
          return http.Response('Unauthorized', 401);
        }),
      );

      client.accessToken = 'expired';
      client.refreshToken = 'bad-refresh';
      client.onAuthFailure = () {
        authFailed = true;
      };

      // Should throw since refresh failed and original was 401
      expect(
        () => client.getSettings(),
        throwsA(isA<MsgrApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
      // Wait for the future to complete
      await Future.delayed(Duration.zero);
      expect(authFailed, isTrue);
    });

    test('does not refresh when no refresh token', () async {
      final client = MsgrApiClient(
        baseUrl: baseUrl,
        httpClient: MockClient((request) async {
          return http.Response('Unauthorized', 401);
        }),
      );

      client.accessToken = 'expired';
      // No refresh token set

      expect(
        () => client.getSettings(),
        throwsA(isA<MsgrApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Error handling
  // ---------------------------------------------------------------------------

  group('error handling', () {
    test('throws MsgrApiException with correct status code on non-2xx', () async {
      final client = buildClient(
        (request) async => http.Response('Not found', 404),
      );

      expect(
        () => client.getSettings(),
        throwsA(isA<MsgrApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.message, 'message', 'Not found')),
      );
    });

    test('throws MsgrApiException on 500', () async {
      final client = buildClient(
        (request) async => http.Response('Internal Server Error', 500),
      );

      expect(
        () => client.getTeams(),
        throwsA(isA<MsgrApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('handles empty response body on success', () async {
      final client = buildClient(
        (request) async => http.Response('', 200),
      );

      final result = await client.getSettings();
      expect(result, isEmpty);
    });
  });
}

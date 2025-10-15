import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:messngr/config/backend_environment.dart';
import 'package:messngr/features/bridges/models/bridge_auth_session.dart';
import 'package:messngr/features/bridges/models/bridge_catalog_entry.dart';
import 'package:messngr/services/api/bridge_api.dart';
import 'package:messngr/services/api/chat_api.dart';

void main() {
  const identity = AccountIdentity(
    accountId: 'acct-1',
    profileId: 'profile-1',
    noiseToken: 'noise-token',
  );

  setUp(() {
    BackendEnvironment.instance.override(
      scheme: 'https',
      host: 'example.com',
      port: 443,
      apiPath: 'api',
    );
  });

  tearDown(() {
    BackendEnvironment.instance.clearOverride();
  });

  test('listCatalog parses bridge entries', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://example.com:443/api/bridges/catalog');
      return http.Response(
        jsonEncode({
          'data': [
            {
              'id': 'telegram',
              'service': 'telegram',
              'display_name': 'Telegram',
              'description': 'desc',
              'status': 'available',
              'auth': {'method': 'oauth', 'auth_surface': 'embedded_browser'},
              'capabilities': {'messaging': {'directions': ['inbound']}},
              'categories': ['consumer'],
              'prerequisites': ['Account'],
              'tags': ['oauth'],
              'auth_paths': {'start': '/auth/bridge/1/start'},
            }
          ]
        }),
        200,
        headers: {'Content-Type': 'application/json'},
      );
    });

    final api = BridgeApi(client: client);
    final entries = await api.listCatalog(current: identity);
    expect(entries, hasLength(1));
    expect(entries.first, isA<BridgeCatalogEntry>());
    expect(entries.first.displayName, 'Telegram');
    expect(entries.first.authSurface, 'embedded_browser');
  });

  test('startSession posts payload and returns session', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(),
          'https://example.com:443/api/bridges/telegram/sessions');
      final decoded = jsonDecode(request.body) as Map<String, dynamic>;
      expect(decoded['session'], {'client_context': {'foo': 'bar'}});
      return http.Response(
        jsonEncode({
          'data': {
            'id': 'session-1',
            'account_id': identity.accountId,
            'service': 'telegram',
            'state': 'awaiting_user',
            'login_method': 'oauth',
            'auth_surface': 'embedded_browser',
            'client_context': {'foo': 'bar'},
            'metadata': {},
            'catalog_snapshot': {},
            'authorization_path': '/auth/bridge/session-1/start',
            'callback_path': '/auth/bridge/session-1/callback',
          }
        }),
        200,
        headers: {'Content-Type': 'application/json'},
      );
    });

    final api = BridgeApi(client: client);
    final session = await api.startSession(
      current: identity,
      bridgeId: 'telegram',
      payload: {'client_context': {'foo': 'bar'}},
    );
    expect(session, isA<BridgeAuthSession>());
    expect(session.authorizationPath, '/auth/bridge/session-1/start');
  });

  test('resolveAuthorizationUrl removes API prefix', () {
    final api = BridgeApi(client: MockClient((_) async => http.Response('{}', 200)));
    final url = api.resolveAuthorizationUrl('/auth/bridge/123/start');
    expect(url.toString(), 'https://example.com:443/auth/bridge/123/start');
  });

  test('unlink issues delete request', () async {
    var deleteCalled = false;
    final client = MockClient((request) async {
      if (request.method == 'DELETE') {
        deleteCalled = true;
        expect(
          request.url.toString(),
          'https://example.com:443/api/bridges/telegram',
        );
        return http.Response('', 204);
      }

      return http.Response('{}', 200);
    });

    final api = BridgeApi(client: client);
    await api.unlink(current: identity, bridgeId: 'telegram');
    expect(deleteCalled, isTrue);
  });
}

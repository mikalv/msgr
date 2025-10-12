import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:messngr/config/backend_environment.dart';
import 'package:messngr/features/bridges/models/bridge_auth_session.dart';
import 'package:messngr/features/bridges/state/bridge_session_controller.dart';
import 'package:messngr/services/api/bridge_api.dart';
import 'package:messngr/services/api/chat_api.dart';

void main() {
  const identity = AccountIdentity(accountId: 'acct-1', profileId: 'profile-1');

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

  test('refresh updates session data', () async {
    var fetchCount = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/sessions/session-1')) {
        fetchCount += 1;
        final body = {
          'data': {
            'id': 'session-1',
            'account_id': 'acct-1',
            'service': 'telegram',
            'state': 'linked',
            'login_method': 'oauth',
            'auth_surface': 'embedded_browser',
            'client_context': {},
            'metadata': {},
            'catalog_snapshot': {},
            'authorization_path': '/auth/bridge/session-1/start',
            'callback_path': '/auth/bridge/session-1/callback',
          },
        };
        return http.Response(jsonEncode(body), 200,
            headers: {'Content-Type': 'application/json'});
      }
      return http.Response('{}', 200);
    });

    final api = BridgeApi(client: client);
    final session = BridgeAuthSession.fromJson({
      'id': 'session-1',
      'account_id': 'acct-1',
      'service': 'telegram',
      'state': 'awaiting_user',
      'login_method': 'oauth',
      'auth_surface': 'embedded_browser',
      'client_context': {},
      'metadata': {},
      'catalog_snapshot': {},
      'authorization_path': '/auth/bridge/session-1/start',
      'callback_path': '/auth/bridge/session-1/callback',
    });

    final controller = BridgeSessionController(
      identity: identity,
      api: api,
      initialSession: session,
      bridgeId: 'telegram',
    );

    expect(controller.session.state, 'awaiting_user');
    await controller.refresh();
    expect(fetchCount, 1);
    expect(controller.session.state, 'linked');
    expect(
      controller.authorizationUrl.toString(),
      'https://example.com:443/auth/bridge/session-1/start',
    );
  });
}

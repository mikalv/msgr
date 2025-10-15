import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:messngr/config/backend_environment.dart';
import 'package:messngr/features/bridges/state/bridge_catalog_controller.dart';
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

  test('load populates entries and filtering works', () async {
    final client = MockClient((request) async {
      final body = {
        'data': [
          {
            'id': 'telegram',
            'service': 'telegram',
            'display_name': 'Telegram',
            'description': 'desc',
            'status': 'available',
            'auth': {'method': 'oauth', 'auth_surface': 'embedded_browser'},
            'capabilities': {},
            'categories': [],
            'prerequisites': [],
            'tags': ['oauth'],
            'auth_paths': {'start': '/auth/start'},
          },
          {
            'id': 'slack',
            'service': 'slack',
            'display_name': 'Slack',
            'description': 'desc',
            'status': 'coming_soon',
            'auth': {'method': 'oauth', 'auth_surface': 'embedded_browser'},
            'capabilities': {},
            'categories': [],
            'prerequisites': [],
            'tags': ['preview'],
            'auth_paths': {'start': '/auth/start'},
          },
        ]
      };
      return http.Response(jsonEncode(body), 200);
    });

    final controller = BridgeCatalogController(
      identity: identity,
      api: _FakeBridgeApi(client: client),
    );

    await controller.load();
    expect(controller.entries, hasLength(2));
    controller.applyFilter('coming_soon');
    expect(controller.visibleEntries, hasLength(1));
    expect(controller.visibleEntries.first.displayName, 'Slack');
  });

  test('disconnect triggers API call and refreshes state', () async {
    var catalogCalls = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path.endsWith('/bridges/catalog')) {
        catalogCalls += 1;
        final linked = catalogCalls == 1;

        final body = {
          'data': [
            {
              'id': 'telegram',
              'service': 'telegram',
              'display_name': 'Telegram',
              'description': 'desc',
              'status': 'available',
              'auth': {
                'method': 'oauth',
                'auth_surface': 'embedded_browser',
                'status': linked ? 'linked' : 'not_linked',
              },
              'link': linked
                  ? {
                      'status': 'linked',
                      'display_name': 'Alice',
                      'external_id': 'tg-1',
                    }
                  : null,
              'capabilities': {},
              'categories': [],
              'prerequisites': [],
              'tags': ['oauth'],
              'auth_paths': {'start': '/auth/start'},
            }
          ]
        };

        return http.Response(jsonEncode(body), 200);
      }

      if (request.method == 'DELETE' &&
          request.url.path.endsWith('/bridges/telegram')) {
        return http.Response('', 204);
      }

      return http.Response('unexpected', 500);
    });

    final controller = BridgeCatalogController(
      identity: identity,
      api: _FakeBridgeApi(client: client),
    );

    await controller.load();
    expect(controller.entries, hasLength(1));
    expect(controller.entries.first.isLinked, isTrue);

    await controller.disconnect(controller.entries.first);

    expect(controller.entries.first.isLinked, isFalse);
    expect(catalogCalls, 2);
  });
}

class _FakeBridgeApi extends BridgeApi {
  _FakeBridgeApi({required http.Client client}) : super(client: client);
}

/// HTTP end-to-end E2EE test against a running Phoenix backend.
///
/// Requires env:
///   E2EE_E2E_BASE_URL   e.g. http://127.0.0.1:4000
///   BOT_AUTH_SECRET     same secret the backend was started with
///
/// Run via scripts/run_e2ee_e2e.sh or:
///   E2EE_E2E_BASE_URL=http://127.0.0.1:4000 BOT_AUTH_SECRET=dev-bot-secret \
///     dart test test/e2ee/e2ee_http_e2e_test.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:libmsgr_core/libmsgr_core.dart';
import 'package:test/test.dart';

const _plaintext = 'e2e-secret-marker-never-on-server';

void main() {
  final baseUrl = Platform.environment['E2EE_E2E_BASE_URL'] ?? '';
  final botSecret = Platform.environment['BOT_AUTH_SECRET'] ?? '';
  final enabled = baseUrl.isNotEmpty && botSecret.isNotEmpty;

  group('E2EE HTTP E2E', () {
    test(
      'two clients XX over REST; server never sees plaintext',
      () async {
        final stamp = DateTime.now().microsecondsSinceEpoch;
        final aliceAuth = await _botLogin(
          baseUrl,
          botSecret,
          'alice-e2e-$stamp@example.com',
        );
        final bobAuth = await _botLogin(
          baseUrl,
          botSecret,
          'bob-e2e-$stamp@example.com',
        );

        final conversationId = await _ensureDirect(
          baseUrl,
          aliceAuth.token,
          bobAuth.profileId,
        );

        final alice = await _service();
        final bob = await _service();

        final init = await alice.prepareSend(
          peerProfileId: bobAuth.profileId,
          plaintext: _plaintext,
        );
        expect(init.queued, isTrue);

        await _postEncrypted(
          baseUrl,
          aliceAuth.token,
          conversationId,
          init.payload,
        );

        final afterInit = await _listMessages(
          baseUrl,
          bobAuth.token,
          conversationId,
        );
        final initMsg = _requireByType(afterInit, 'init');
        _assertOpaque(initMsg);

        final bobHandle = await bob.handleIncoming(
          peerProfileId: aliceAuth.profileId,
          payload: Map<String, dynamic>.from(initMsg['payload'] as Map),
        );
        expect(bobHandle.ackPayload, isNotNull);

        await _postEncrypted(
          baseUrl,
          bobAuth.token,
          conversationId,
          bobHandle.ackPayload!,
        );

        final afterAck = await _listMessages(
          baseUrl,
          aliceAuth.token,
          conversationId,
        );
        final ackMsg = _requireByType(afterAck, 'init_ack');
        _assertOpaque(ackMsg);

        await alice.handleIncoming(
          peerProfileId: bobAuth.profileId,
          payload: Map<String, dynamic>.from(ackMsg['payload'] as Map),
        );

        final flushed = await alice.flushPending(
          peerProfileId: bobAuth.profileId,
        );
        expect(flushed, hasLength(1));
        expect(flushed.single.payload.toString().contains(_plaintext), isFalse);

        await _postEncrypted(
          baseUrl,
          aliceAuth.token,
          conversationId,
          flushed.single.payload,
        );

        final bobHistory = await _listMessages(
          baseUrl,
          bobAuth.token,
          conversationId,
        );
        final cipherMsg = _requireByType(bobHistory, 'msg');
        _assertOpaque(cipherMsg);
        expect(jsonEncode(bobHistory).contains(_plaintext), isFalse);

        final decrypted = await bob.handleIncoming(
          peerProfileId: aliceAuth.profileId,
          payload: Map<String, dynamic>.from(cipherMsg['payload'] as Map),
        );
        expect(decrypted.plaintext, _plaintext);
      },
      skip: enabled
          ? false
          : 'Set E2EE_E2E_BASE_URL and BOT_AUTH_SECRET to run HTTP E2E',
    );
  });
}

class _Auth {
  _Auth({required this.token, required this.profileId});
  final String token;
  final String profileId;
}

Future<E2eeService> _service() async {
  final storage = MemorySecureStorage();
  final keys = KeyManager(storage: storage);
  await keys.getOrGenerateDeviceId();
  return E2eeService(keyManager: keys, store: MemoryE2eeSessionStore());
}

Future<_Auth> _botLogin(String base, String secret, String email) async {
  final res = await http.post(
    Uri.parse('$base/api/v1/auth/bot-token'),
    headers: {'content-type': 'application/json'},
    body: jsonEncode({'email': email, 'bot_secret': secret}),
  );
  expect(res.statusCode, anyOf(200, 201), reason: res.body);
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final token = data['access_token'] as String;
  final profileId = data['profile_id'] as String? ??
      (data['profile'] as Map?)?['id'] as String?;
  expect(profileId, isNotNull);
  return _Auth(token: token, profileId: profileId!);
}

Future<String> _ensureDirect(
  String base,
  String token,
  String peerProfileId,
) async {
  final res = await http.post(
    Uri.parse('$base/api/conversations'),
    headers: {
      'content-type': 'application/json',
      'authorization': 'Bearer $token',
    },
    body: jsonEncode({'target_profile_id': peerProfileId}),
  );
  expect(res.statusCode, anyOf(200, 201), reason: res.body);
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final id = (data['data'] as Map?)?['id'] as String? ?? data['id'] as String?;
  expect(id, isNotNull);
  return id!;
}

Future<void> _postEncrypted(
  String base,
  String token,
  String conversationId,
  Map<String, dynamic> payload,
) async {
  final res = await http.post(
    Uri.parse('$base/api/conversations/$conversationId/messages'),
    headers: {
      'content-type': 'application/json',
      'authorization': 'Bearer $token',
    },
    body: jsonEncode({
      'message': {
        'kind': 'encrypted',
        'body': '',
        'payload': payload,
      },
    }),
  );
  expect(res.statusCode, 201, reason: res.body);
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  _assertOpaque(data['data'] as Map<String, dynamic>);
}

Future<List<Map<String, dynamic>>> _listMessages(
  String base,
  String token,
  String conversationId,
) async {
  final res = await http.get(
    Uri.parse('$base/api/conversations/$conversationId/messages'),
    headers: {'authorization': 'Bearer $token'},
  );
  expect(res.statusCode, 200, reason: res.body);
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  return (data['data'] as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
}

void _assertOpaque(Map<String, dynamic> msg) {
  expect(msg['type'], 'encrypted');
  expect(msg['body'] == null || msg['body'] == '', isTrue);
  expect(msg['payload'], isA<Map>());
  expect((msg['payload'] as Map)['e2ee'], isA<Map>());
  expect(jsonEncode(msg).contains(_plaintext), isFalse);
}

Map<String, dynamic> _requireByType(
  List<Map<String, dynamic>> messages,
  String type,
) {
  for (final msg in messages) {
    final e2ee = (msg['payload'] as Map?)?['e2ee'] as Map?;
    final keys = e2ee?['keys'] as List? ?? const [];
    for (final key in keys) {
      if (key is Map && key['type'] == type) {
        return msg;
      }
    }
  }
  fail('No encrypted message with key type "$type" in ${messages.length} msgs');
}

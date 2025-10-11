import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:libmsgr/src/services/contact_api.dart';
import 'package:test/test.dart';

void main() {
  group('ContactApiClient', () {
    const context = ContactApiContext(accountId: 'acct-1', profileId: 'profile-1');

    test('imports contacts and returns parsed records', () async {
      late http.Request capturedRequest;

      final client = MockClient((request) async {
        capturedRequest = request;
        expect(request.method, equals('POST'));
        expect(request.url.toString(), equals('http://teams.7f000001.nip.io:4080/api/contacts/import'));
        expect(
          request.headers,
          containsPair('x-account-id', context.accountId),
        );
        expect(
          request.headers,
          containsPair('x-profile-id', context.profileId),
        );

        final decoded = jsonDecode(request.body) as Map<String, dynamic>;
        expect(decoded['contacts'], isA<List>());
        final first = (decoded['contacts'] as List).single as Map<String, dynamic>;
        expect(first['name'], equals('Eva'));
        expect(first['email'], equals('eva@example.com'));
        expect(first['labels'], equals(['venn']));

        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'contact-1',
                'name': 'Eva',
                'email': 'eva@example.com',
                'phone_number': '4790000000',
                'labels': ['venn'],
                'metadata': {'source': 'device'},
                'account_id': 'acct-1',
                'profile_id': 'profile-1',
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ContactApiClient(client: client);

      final records = await api.importContacts(
        context: context,
        contacts: const [
          ContactImportEntry(
            name: 'Eva',
            email: 'eva@example.com',
            labels: ['venn'],
          ),
        ],
      );

      expect(records, hasLength(1));
      final record = records.single;
      expect(record.id, equals('contact-1'));
      expect(record.metadata, equals({'source': 'device'}));
      expect(record.accountId, equals('acct-1'));
      expect(record.profileId, equals('profile-1'));

      // Ensure request captured to avoid analyzer warnings.
      expect(capturedRequest, isNotNull);
    });

    test('looks up known contacts and exposes matches', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), equals('http://teams.7f000001.nip.io:4080/api/contacts/lookup'));

        return http.Response(
          jsonEncode({
            'data': [
              {
                'query': {'email': 'eva@example.com', 'phone_number': null},
                'match': {
                  'account_id': 'acct-2',
                  'account_name': 'Eva',
                  'identity_kind': 'email',
                  'identity_value': 'eva@example.com',
                  'profile': {
                    'id': 'profile-2',
                    'name': 'Privat',
                    'mode': 'personal'
                  }
                }
              },
              {
                'query': {'email': null, 'phone_number': '4790000000'},
                'match': null
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ContactApiClient(client: client);

      final matches = await api.lookupKnownContacts(
        context: context,
        targets: const [
          ContactLookupTarget(email: 'eva@example.com'),
          ContactLookupTarget(phoneNumber: '4790000000'),
        ],
      );

      expect(matches, hasLength(2));
      expect(matches.first.hasMatch, isTrue);
      expect(matches.first.match!.profile!.id, equals('profile-2'));
      expect(matches.last.hasMatch, isFalse);
    });

    test('throws ContactApiException on non-success status codes', () async {
      final client = MockClient((request) async {
        return http.Response('nope', 500);
      });

      final api = ContactApiClient(client: client);

      expect(
        () => api.importContacts(context: context, contacts: const []),
        throwsA(isA<ContactApiException>().having((e) => e.statusCode, 'status', 500)),
      );
    });
  });
}

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../server_resolver.dart';

class ContactImportEntry {
  const ContactImportEntry({
    this.name,
    this.email,
    this.phoneNumber,
    this.labels = const [],
    this.metadata = const <String, dynamic>{},
  });

  final String? name;
  final String? email;
  final String? phoneNumber;
  final List<String> labels;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (labels.isNotEmpty) 'labels': labels,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}

class ContactLookupTarget {
  const ContactLookupTarget({this.email, this.phoneNumber});

  final String? email;
  final String? phoneNumber;

  Map<String, dynamic> toJson() {
    return {
      if (email != null) 'email': email,
      if (phoneNumber != null) 'phone_number': phoneNumber,
    };
  }
}

class ContactApiContext {
  const ContactApiContext({required this.accountId, required this.profileId});

  final String accountId;
  final String profileId;
}

class ContactRecord {
  const ContactRecord({
    required this.id,
    required this.name,
    this.email,
    this.phoneNumber,
    this.labels = const [],
    this.metadata = const <String, dynamic>{},
    this.accountId,
    this.profileId,
  });

  final String id;
  final String name;
  final String? email;
  final String? phoneNumber;
  final List<String> labels;
  final Map<String, dynamic> metadata;
  final String? accountId;
  final String? profileId;

  factory ContactRecord.fromJson(Map<String, dynamic> json) {
    final metadataValue = json['metadata'];
    final labelsValue = json['labels'];

    return ContactRecord(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      phoneNumber: json['phone_number'] as String?,
      labels: labelsValue is List
          ? labelsValue.map((item) => item.toString()).toList(growable: false)
          : const [],
      metadata: _coerceMetadata(metadataValue),
      accountId: json['account_id'] as String?,
      profileId: json['profile_id'] as String?,
    );
  }
}

class ContactProfileSummary {
  const ContactProfileSummary({
    required this.id,
    required this.name,
    required this.mode,
  });

  final String id;
  final String name;
  final String mode;

  factory ContactProfileSummary.fromJson(Map<String, dynamic> json) {
    return ContactProfileSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      mode: json['mode'].toString(),
    );
  }
}

class ContactMatchDetails {
  const ContactMatchDetails({
    required this.accountId,
    required this.accountName,
    required this.identityKind,
    required this.identityValue,
    this.profile,
  });

  final String accountId;
  final String accountName;
  final String identityKind;
  final String identityValue;
  final ContactProfileSummary? profile;

  factory ContactMatchDetails.fromJson(Map<String, dynamic> json) {
    final profileValue = json['profile'];

    return ContactMatchDetails(
      accountId: json['account_id'] as String,
      accountName: json['account_name'] as String,
      identityKind: json['identity_kind'].toString(),
      identityValue: json['identity_value']?.toString() ?? '',
      profile: profileValue is Map<String, dynamic>
          ? ContactProfileSummary.fromJson(profileValue)
          : null,
    );
  }
}

class KnownContactMatch {
  const KnownContactMatch({
    required this.queryEmail,
    required this.queryPhoneNumber,
    this.match,
  });

  final String? queryEmail;
  final String? queryPhoneNumber;
  final ContactMatchDetails? match;

  bool get hasMatch => match != null;

  factory KnownContactMatch.fromJson(Map<String, dynamic> json) {
    final query = json['query'];

    return KnownContactMatch(
      queryEmail: query is Map<String, dynamic> ? query['email'] as String? : null,
      queryPhoneNumber:
          query is Map<String, dynamic> ? query['phone_number'] as String? : null,
      match: json['match'] is Map<String, dynamic>
          ? ContactMatchDetails.fromJson(json['match'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ContactApiException implements Exception {
  ContactApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() {
    return 'ContactApiException(statusCode: $statusCode, body: $body)';
  }
}

class ContactApiClient {
  ContactApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<ContactRecord>> importContacts({
    required ContactApiContext context,
    required List<ContactImportEntry> contacts,
  }) async {
    final response = await _client.post(
      ServerResolver.getMainServer('/api/contacts/import'),
      headers: _headers(context),
      body: jsonEncode({
        'contacts': contacts.map((entry) => entry.toJson()).toList(),
      }),
    );

    final decoded = _decode(response);
    final data = decoded['data'];

    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(ContactRecord.fromJson)
          .toList(growable: false);
    }

    return const [];
  }

  Future<List<KnownContactMatch>> lookupKnownContacts({
    required ContactApiContext context,
    required List<ContactLookupTarget> targets,
  }) async {
    final response = await _client.post(
      ServerResolver.getMainServer('/api/contacts/lookup'),
      headers: _headers(context),
      body: jsonEncode({
        'targets': targets.map((entry) => entry.toJson()).toList(),
      }),
    );

    final decoded = _decode(response);
    final data = decoded['data'];

    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(KnownContactMatch.fromJson)
          .toList(growable: false);
    }

    return const [];
  }

  void close() {
    _client.close();
  }

  Map<String, String> _headers(ContactApiContext context) {
    return {
      'Content-Type': 'application/json',
      'x-account-id': context.accountId,
      'x-profile-id': context.profileId,
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.isEmpty ? '{}' : response.body;
    final decoded = jsonDecode(body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw ContactApiException(response.statusCode, response.body);
  }
}

Map<String, dynamic> _coerceMetadata(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, entryValue) => MapEntry(key.toString(), entryValue));
  }

  return const {};
}

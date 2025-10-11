import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:messngr/config/app_constants.dart';

import 'chat_api.dart' show AccountIdentity, ApiException;

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
    return ContactRecord(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      phoneNumber: json['phone_number'] as String?,
      labels: (json['labels'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      metadata: (json['metadata'] as Map<String, dynamic>? ?? const {}),
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
    return ContactMatchDetails(
      accountId: json['account_id'] as String,
      accountName: json['account_name'] as String,
      identityKind: json['identity_kind'].toString(),
      identityValue: json['identity_value']?.toString() ?? '',
      profile: json['profile'] == null
          ? null
          : ContactProfileSummary.fromJson(json['profile'] as Map<String, dynamic>),
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
    final query = json['query'] as Map<String, dynamic>? ?? const {};
    return KnownContactMatch(
      queryEmail: query['email'] as String?,
      queryPhoneNumber: query['phone_number'] as String?,
      match: json['match'] == null
          ? null
          : ContactMatchDetails.fromJson(json['match'] as Map<String, dynamic>),
    );
  }
}

class ContactApi {
  ContactApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<ContactRecord>> importContacts({
    required AccountIdentity current,
    required List<ContactImportEntry> contacts,
  }) async {
    final response = await _client.post(
      backendApiUri('contacts/import'),
      headers: _authHeaders(current),
      body: jsonEncode({
        'contacts': contacts.map((entry) => entry.toJson()).toList(),
      }),
    );

    final decoded = _decodeBody(response);
    final data = decoded['data'] as List<dynamic>? ?? const [];

    return data
        .map((raw) => ContactRecord.fromJson(raw as Map<String, dynamic>))
        .toList();
  }

  Future<List<KnownContactMatch>> lookupKnownContacts({
    required AccountIdentity current,
    required List<ContactImportEntry> targets,
  }) async {
    final response = await _client.post(
      backendApiUri('contacts/lookup'),
      headers: _authHeaders(current),
      body: jsonEncode({
        'targets': targets.map((entry) => entry.toJson()).toList(),
      }),
    );

    final decoded = _decodeBody(response);
    final data = decoded['data'] as List<dynamic>? ?? const [];

    return data
        .map((raw) => KnownContactMatch.fromJson(raw as Map<String, dynamic>))
        .toList();
  }

  Map<String, String> _authHeaders(AccountIdentity identity) {
    return {
      'Content-Type': 'application/json',
      'x-account-id': identity.accountId,
      'x-profile-id': identity.profileId,
    };
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    final body = response.body.isEmpty ? '{}' : response.body;
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    throw ApiException(response.statusCode, response.body);
  }
}

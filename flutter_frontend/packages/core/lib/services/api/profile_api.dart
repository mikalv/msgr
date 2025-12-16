import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/services/api/chat_api.dart';

class ProfileSwitchResult {
  const ProfileSwitchResult({
    required this.profile,
    required this.identity,
    this.device,
  });

  final Profile profile;
  final AccountIdentity identity;
  final Map<String, dynamic>? device;
}

class ProfileApi {
  ProfileApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<Profile>> listProfiles({
    required AccountIdentity identity,
  }) async {
    final response = await _client.get(
      backendApiUri('profiles'),
      headers: _headers(identity),
    );

    final decoded = _decodeBody(response);
    final data = decoded['data'] as List<dynamic>? ?? const [];
    return data
        .map((raw) => Profile.fromJson(raw as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Profile> updateProfile({
    required AccountIdentity identity,
    required String profileId,
    required Map<String, dynamic> changes,
  }) async {
    final response = await _client.patch(
      backendApiUri('profiles/$profileId'),
      headers: _headers(identity),
      body: jsonEncode({'profile': changes}),
    );

    final decoded = _decodeBody(response);
    final data = decoded['data'] as Map<String, dynamic>? ?? const {};
    return Profile.fromJson(data);
  }

  Future<void> deleteProfile({
    required AccountIdentity identity,
    required String profileId,
  }) async {
    final response = await _client.delete(
      backendApiUri('profiles/$profileId'),
      headers: _headers(identity),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }
  }

  Future<ProfileSwitchResult> switchProfile({
    required AccountIdentity identity,
    required String profileId,
  }) async {
    final response = await _client.post(
      backendApiUri('profiles/$profileId/switch'),
      headers: _headers(identity),
    );

    final decoded = _decodeBody(response);
    final data = decoded['data'] as Map<String, dynamic>? ?? const {};
    final profileMap = data['profile'] as Map<String, dynamic>? ?? const {};
    final sessionMap = data['noise_session'] as Map<String, dynamic>? ?? const {};
    final profile = Profile.fromJson(profileMap);
    final token = sessionMap['token'] as String? ?? identity.noiseToken;

    final updatedIdentity = AccountIdentity(
      accountId: identity.accountId,
      profileId: profile.id,
      noiseToken: token,
      noiseSessionId: identity.noiseSessionId,
    );

    final device = data['device'];
    final deviceMap = device is Map<String, dynamic> ? device : null;

    return ProfileSwitchResult(
      profile: profile,
      identity: updatedIdentity,
      device: deviceMap,
    );
  }

  Map<String, String> _headers(AccountIdentity identity) {
    final token = identity.noiseToken.trim();
    if (token.isEmpty) {
      throw ApiException(
        401,
        'Missing Noise session token for account ${identity.accountId}',
      );
    }

    return {
      'Content-Type': 'application/json',
      'x-account-id': identity.accountId,
      'x-profile-id': identity.profileId,
      'Authorization': 'Noise $token',
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

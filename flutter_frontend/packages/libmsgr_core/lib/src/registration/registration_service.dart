import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:logging/logging.dart';

import '../constants.dart';
import '../contracts/device.dart';
import '../contracts/storage.dart';
import '../crypto/key_manager.dart';
import '../models/auth_challenge.dart';
import '../models/noise_handshake.dart';
import 'registration_api.dart';

class RegistrationServiceCore {
  RegistrationServiceCore({
    required this.keyManager,
    required this.secureStorage,
    required this.deviceInfoProvider,
    RegistrationApi? api,
    String? registrationFlagKey,
  })  : _api = api ?? RegistrationApi(),
        _registeredFlag =
            registrationFlagKey ?? MsgrConstants.kIsDeviceRegisteredWithServerNameStr,
        _log = Logger('RegistrationServiceCore');

  final KeyManager keyManager;
  final SecureStorage secureStorage;
  final DeviceInfoProvider deviceInfoProvider;
  final RegistrationApi _api;
  final String _registeredFlag;
  final Logger _log;

  Map<String, dynamic>? _cachedDeviceInfo;
  Map<String, dynamic>? _cachedAppInfo;
  String? email;
  String? msisdn;
  AuthChallenge? lastChallenge;
  NoiseHandshakeSession? _noiseHandshake;

  void updateCachedContext({
    required Map<String, dynamic> deviceInfo,
    required Map<String, dynamic> appInfo,
  }) {
    _cachedDeviceInfo = Map<String, dynamic>.from(deviceInfo);
    _cachedAppInfo = Map<String, dynamic>.from(appInfo);
  }

  Future<Map<String, dynamic>> _deviceInfoForRequest(
      Map<String, dynamic>? overrideDeviceInfo) async {
    if (overrideDeviceInfo != null) {
      return Map<String, dynamic>.from(overrideDeviceInfo);
    }
    if (_cachedDeviceInfo != null) {
      return Map<String, dynamic>.from(_cachedDeviceInfo!);
    }
    return await deviceInfoProvider.deviceInfo();
  }

  Map<String, dynamic> _appInfoForRequest(
      Map<String, dynamic>? overrideAppInfo) {
    final resolved = overrideAppInfo ?? _cachedAppInfo ?? const {};
    return Map<String, dynamic>.from(resolved);
  }

  Future<void> ensureKeysLoaded() async {
    if (keyManager.isLoading) {
      await keyManager.getOrGenerateDeviceId();
    }
  }

  Future<void> maybeRegisterDevice({
    Map<String, dynamic>? deviceInfo,
    Map<String, dynamic>? appInfo,
  }) async {
    await ensureKeysLoaded();

    final exists = await secureStorage.containsKey(_registeredFlag);
    if (!exists) {
      final success = await registerDevice(
        deviceInfo: deviceInfo,
        appInfo: appInfo,
      );
      if (success) {
        await secureStorage.writeValue(_registeredFlag, keyManager.deviceId);
      }
    }
  }

  Future<bool> registerDevice({
    Map<String, dynamic>? deviceInfo,
    Map<String, dynamic>? appInfo,
  }) async {
    await ensureKeysLoaded();
    final keyData = await keyManager.getDataForServer();
    final resolvedDeviceInfo = await _deviceInfoForRequest(deviceInfo);
    final resolvedAppInfo = _appInfoForRequest(appInfo);

    final success = await _api.registerDevice(
      deviceId: keyManager.deviceId,
      keyData: keyData,
      deviceInfo: resolvedDeviceInfo,
      appInfo: resolvedAppInfo.isNotEmpty ? resolvedAppInfo : null,
    );
    if (!success) {
      _log.warning('Device registration failed for ${keyManager.deviceId}');
    }
    return success;
  }

  Future<bool> syncDeviceContext({
    Map<String, dynamic>? deviceInfo,
    Map<String, dynamic>? appInfo,
  }) async {
    await ensureKeysLoaded();
    final resolvedDeviceInfo = await _deviceInfoForRequest(deviceInfo);
    final resolvedAppInfo = _appInfoForRequest(appInfo);

    return _api.syncDeviceContext(
      deviceId: keyManager.deviceId,
      deviceInfo: resolvedDeviceInfo,
      appInfo: resolvedAppInfo.isNotEmpty ? resolvedAppInfo : null,
    );
  }

  Future<AuthChallenge?> requestChallenge({
    required String channel,
    required String identifier,
  }) async {
    await ensureKeysLoaded();
    final handshake = await _ensureNoiseHandshake();
    final deviceId = handshake?.deviceKey ?? keyManager.deviceId;

    final challenge = await _api.requestChallenge(
      channel: channel,
      identifier: identifier,
      deviceId: deviceId,
    );
    if (challenge != null) {
      lastChallenge = challenge;
    }
    return challenge;
  }

  Future<UserSession?> verifyCode({
    required String challengeId,
    required String code,
    String? displayName,
  }) async {
    await ensureKeysLoaded();
    final handshake = _noiseHandshake ?? await _ensureNoiseHandshake(refreshIfNeeded: false);
    final response = await _api.verifyCode(
      challengeId: challengeId,
      code: code,
      displayName: displayName,
      noiseSessionId: handshake?.sessionId,
      noiseSignature: handshake?.signature,
      lastHandshakeAt: handshake != null ? DateTime.now().toUtc() : null,
    );
    if (response == null) {
      return null;
    }

    _clearNoiseHandshake();

    final account = response['account'] as Map<String, dynamic>;
    final identity = response['identity'] as Map<String, dynamic>;
    final identifier =
        account['email'] ?? account['phone_number'] ?? identity['kind'];

    return UserSession(
      userId: account['id'] as String?,
      identifier: identifier as String,
      accessToken: identity['id'] as String,
      refreshToken: identity['id'] as String,
    );
  }

  Future<UserSession?> completeOidc({
    required String provider,
    required String subject,
    String? email,
    String? name,
  }) async {
    final response = await _api.completeOidc(
      provider: provider,
      subject: subject,
      email: email,
      name: name,
    );
    if (response == null) {
      return null;
    }
    final account = response['account'] as Map<String, dynamic>;
    final identity = response['identity'] as Map<String, dynamic>;
    final identifier =
        account['email'] ?? account['phone_number'] ?? identity['kind'];
    return UserSession(
      userId: account['id'] as String?,
      identifier: identifier as String,
      accessToken: identity['id'] as String,
      refreshToken: identity['id'] as String,
    );
  }

  Future<Map<String, dynamic>?> selectTeam({
    required String teamName,
    required String token,
  }) async {
    return _api.selectTeam(teamName: teamName, token: token);
  }

  Future<ProfileResult?> createProfile({
    required String teamName,
    required String token,
    required String username,
    required String firstName,
    required String lastName,
  }) async {
    final payload = {
      'first_name': firstName,
      'last_name': lastName,
      'username': username,
    };

    final response = await _api.createProfile(
      teamName: teamName,
      token: token,
      body: payload,
    );

    if (response == null) {
      return null;
    }

    return ProfileResult.fromJson(response);
  }

  Future<TeamCreationResult?> createTeam({
    required String teamName,
    required String description,
    required String token,
  }) async {
    final decodedToken = JwtDecoder.decode(token);
    final response = await _api.createTeam(
      teamName: teamName,
      description: description,
      token: token,
      uid: decodedToken['sub'] as String,
    );
    if (response == null || response['status'] != 'ok') {
      return null;
    }
    return TeamCreationResult.fromJson(response);
  }

  Future<List<Map<String, dynamic>>> listTeams({
    required String token,
  }) async {
    final teams = await _api.listTeams(token: token);
    return teams.cast<Map<String, dynamic>>();
  }

  Future<RefreshSessionResponse?> refreshSession({
    required String refreshToken,
  }) async {
    await ensureKeysLoaded();
    final response = await _api.refreshSession(
      deviceId: keyManager.deviceId,
      refreshToken: refreshToken,
    );
    if (response == null || response['status'] != 'ok') {
      return null;
    }
    final token = response['token'] as String?;
    final refresh = response['refresh_token'] as String?;
    if (token == null || refresh == null) {
      return null;
    }
    return RefreshSessionResponse(accessToken: token, refreshToken: refresh);
  }

  Future<NoiseHandshakeSession?> _ensureNoiseHandshake({bool refreshIfNeeded = true}) async {
    final current = _noiseHandshake;

    if (!refreshIfNeeded) {
      return current;
    }

    if (current != null && !current.shouldRefresh && !current.isExpired) {
      return current;
    }

    final session = await _api.createNoiseHandshake();

    if (session == null ||
        session.sessionId.isEmpty ||
        session.signature.isEmpty ||
        session.deviceKey.isEmpty) {
      _log.fine('Noise handshake endpoint unavailable or returned incomplete data');
      _noiseHandshake = null;
      return null;
    }

    _noiseHandshake = session;
    return _noiseHandshake;
  }

  void _clearNoiseHandshake() {
    _noiseHandshake = null;
  }
}

class UserSession {
  const UserSession({
    required this.userId,
    required this.identifier,
    required this.accessToken,
    required this.refreshToken,
  });

  final String? userId;
  final String identifier;
  final String accessToken;
  final String refreshToken;
}

class TeamCreationResult {
  const TeamCreationResult({
    required this.team,
  });

  final Map<String, dynamic> team;

  factory TeamCreationResult.fromJson(Map<String, dynamic> json) {
    return TeamCreationResult(team: json['team'] as Map<String, dynamic>);
  }
}

class ProfileResult {
  const ProfileResult({
    required this.id,
    required this.data,
  });

  final String? id;
  final Map<String, dynamic> data;

  factory ProfileResult.fromJson(Map<String, dynamic> json) {
    final profile =
        (json['profile'] as Map<String, dynamic>?) ?? json;
    return ProfileResult(
      id: profile['id'] as String?,
      data: profile,
    );
  }
}

class RefreshSessionResponse {
  const RefreshSessionResponse({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}

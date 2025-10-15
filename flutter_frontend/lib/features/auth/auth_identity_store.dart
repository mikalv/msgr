import 'package:messngr/services/api/chat_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the current account/profile identity locally so the chat feature
/// can reconnect without å måtte autogenere demo-brukere.
class AuthIdentityStore {
  AuthIdentityStore._();

  static final AuthIdentityStore instance = AuthIdentityStore._();

  static const _accountIdKey = 'auth.account.id';
  static const _profileIdKey = 'auth.profile.id';
  static const _displayNameKey = 'auth.display.name';
  static const _noiseTokenKey = 'auth.noise.token';
  static const _noiseSessionIdKey = 'auth.noise.session';
  static const _devicePrivateKeyKey = 'auth.device.private';
  static const _devicePublicKeyKey = 'auth.device.public';

  Future<AccountIdentity?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final accountId = prefs.getString(_accountIdKey);
    final profileId = prefs.getString(_profileIdKey);
    final noiseToken = prefs.getString(_noiseTokenKey);
    final noiseSessionId = prefs.getString(_noiseSessionIdKey);
    if (accountId == null || profileId == null || noiseToken == null) {
      return null;
    }

    return AccountIdentity(
      accountId: accountId,
      profileId: profileId,
      noiseToken: noiseToken,
      noiseSessionId: noiseSessionId,
    );
  }

  Future<void> save(
    AccountIdentity identity, {
    String? displayName,
    String? noiseSessionId,
    String? devicePrivateKey,
    String? devicePublicKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accountIdKey, identity.accountId);
    await prefs.setString(_profileIdKey, identity.profileId);
    await prefs.setString(_noiseTokenKey, identity.noiseToken);
    if (noiseSessionId != null && noiseSessionId.isNotEmpty) {
      await prefs.setString(_noiseSessionIdKey, noiseSessionId);
    }
    if (devicePrivateKey != null && devicePrivateKey.isNotEmpty) {
      await prefs.setString(_devicePrivateKeyKey, devicePrivateKey);
    }
    if (devicePublicKey != null && devicePublicKey.isNotEmpty) {
      await prefs.setString(_devicePublicKeyKey, devicePublicKey);
    }
    if (displayName != null && displayName.isNotEmpty) {
      await prefs.setString(_displayNameKey, displayName);
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accountIdKey);
    await prefs.remove(_profileIdKey);
    await prefs.remove(_displayNameKey);
    await prefs.remove(_noiseTokenKey);
    await prefs.remove(_noiseSessionIdKey);
    await prefs.remove(_devicePrivateKeyKey);
    await prefs.remove(_devicePublicKeyKey);
  }

  Future<String?> displayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_displayNameKey);
  }

  Future<String?> devicePrivateKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_devicePrivateKeyKey);
  }

  Future<String?> devicePublicKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_devicePublicKeyKey);
  }
}

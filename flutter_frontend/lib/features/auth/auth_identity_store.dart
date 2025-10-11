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

  Future<AccountIdentity?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final accountId = prefs.getString(_accountIdKey);
    final profileId = prefs.getString(_profileIdKey);
    if (accountId == null || profileId == null) {
      return null;
    }

    return AccountIdentity(accountId: accountId, profileId: profileId);
  }

  Future<void> save(AccountIdentity identity, {String? displayName}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accountIdKey, identity.accountId);
    await prefs.setString(_profileIdKey, identity.profileId);
    if (displayName != null && displayName.isNotEmpty) {
      await prefs.setString(_displayNameKey, displayName);
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accountIdKey);
    await prefs.remove(_profileIdKey);
    await prefs.remove(_displayNameKey);
  }

  Future<String?> displayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_displayNameKey);
  }
}

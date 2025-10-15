import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/features/auth/auth_identity_store.dart';
import 'package:messngr/services/api/chat_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthIdentityStore', () {
    late AuthIdentityStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = AuthIdentityStore.instance;
      await store.clear();
    });

    test('persists and loads identity with noise session', () async {
      const identity = AccountIdentity(
        accountId: 'acc-1',
        profileId: 'profile-1',
        noiseToken: 'noise-token',
        noiseSessionId: 'noise-session',
      );

      await store.save(
        identity,
        displayName: 'Test Bruker',
        noiseSessionId: identity.noiseSessionId,
        devicePrivateKey: 'private-key',
        devicePublicKey: 'public-key',
      );

      final loaded = await store.load();
      expect(loaded, isNotNull);
      expect(loaded!.accountId, equals(identity.accountId));
      expect(loaded.profileId, equals(identity.profileId));
      expect(loaded.noiseToken, equals(identity.noiseToken));
      expect(loaded.noiseSessionId, equals(identity.noiseSessionId));

      final displayName = await store.displayName();
      expect(displayName, equals('Test Bruker'));

      expect(await store.devicePrivateKey(), equals('private-key'));
      expect(await store.devicePublicKey(), equals('public-key'));
    });

    test('clear removes persisted values', () async {
      const identity = AccountIdentity(
        accountId: 'acc-1',
        profileId: 'profile-1',
        noiseToken: 'noise-token',
        noiseSessionId: 'noise-session',
      );

      await store.save(identity);
      await store.clear();

      final loaded = await store.load();
      expect(loaded, isNull);
      expect(await store.displayName(), isNull);
      expect(await store.devicePrivateKey(), isNull);
      expect(await store.devicePublicKey(), isNull);
    });
  });
}

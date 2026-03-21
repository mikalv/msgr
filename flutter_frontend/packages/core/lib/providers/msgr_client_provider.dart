import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libmsgr/api.dart';

import 'auth_state_provider.dart';

/// Global [MsgrClient] provider.
///
/// The client's credentials are kept in sync with [simpleAuthProvider].
/// All API and realtime communication should go through this provider.
final msgrClientProvider = Provider<MsgrClient>((ref) {
  final client = MsgrClient(baseUrl: 'https://dev.msgr.no');

  // Keep MsgrClient credentials in sync with auth state.
  final auth = ref.watch(simpleAuthProvider);
  if (auth.accountId != null && auth.profileId != null) {
    client.setCredentials(
      accountId: auth.accountId!,
      profileId: auth.profileId!,
      accessToken: auth.accessToken,
      refreshToken: auth.refreshToken,
    );
  }

  // Wire up token refresh callbacks to persist new tokens.
  client.api.onTokensRefreshed = (accessToken, refreshToken) {
    ref.read(simpleAuthProvider.notifier).updateTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  };

  // Wire up auth failure to trigger logout.
  client.api.onAuthFailure = () {
    ref.read(simpleAuthProvider.notifier).logout();
  };

  ref.onDispose(() => client.dispose());
  return client;
});

/// Convenience: the [MsgrApiClient] from the global client.
final msgrApiProvider = Provider<MsgrApiClient>((ref) {
  return ref.watch(msgrClientProvider).api;
});

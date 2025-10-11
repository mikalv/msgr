import 'package:flutter_test/flutter_test.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/app/bootstrap/session_refresher.dart';

class _FakeSessionRefreshClient implements SessionRefreshClient {
  _FakeSessionRefreshClient({this.response});

  int callCount = 0;
  RefreshSessionResponse? response;

  @override
  Future<RefreshSessionResponse?> refresh(String refreshToken) async {
    callCount += 1;
    return response;
  }
}

void main() {
  test('returns null when token is not expired', () async {
    final client = _FakeSessionRefreshClient();
    final refresher = SessionRefresher(
      client: client,
      tokenExpiryEvaluator: (_) => false,
    );

    final user = User(
      id: '1',
      identifier: 'user@example.com',
      accessToken: 'access',
      refreshToken: 'refresh',
    );

    final refreshed = await refresher.refreshIfExpired(user);

    expect(refreshed, isNull);
    expect(client.callCount, 0);
  });

  test('returns updated user when token is expired', () async {
    final client = _FakeSessionRefreshClient(
      response: const RefreshSessionResponse(
        accessToken: 'new_access',
        refreshToken: 'new_refresh',
      ),
    );
    final refresher = SessionRefresher(
      client: client,
      tokenExpiryEvaluator: (_) => true,
    );

    final user = User(
      id: '1',
      identifier: 'user@example.com',
      accessToken: 'old_access',
      refreshToken: 'old_refresh',
    );

    final refreshed = await refresher.refreshIfExpired(user);

    expect(refreshed, isNotNull);
    expect(refreshed!.accessToken, 'new_access');
    expect(refreshed.refreshToken, 'new_refresh');
    expect(client.callCount, 1);
  });

  test('throws when refresh client fails to return response', () async {
    final client = _FakeSessionRefreshClient(response: null);
    final refresher = SessionRefresher(
      client: client,
      tokenExpiryEvaluator: (_) => true,
    );

    final user = User(
      id: '1',
      identifier: 'user@example.com',
      accessToken: 'expired',
      refreshToken: 'refresh',
    );

    expect(
      () => refresher.refreshIfExpired(user),
      throwsA(isA<SessionRefreshException>()),
    );
  });
}

import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/registration_service.dart';
import 'package:logging/logging.dart';

typedef TokenExpiryEvaluator = bool Function(String token);

abstract class SessionRefreshClient {
  Future<RefreshSessionResponse?> refresh(String refreshToken);
}

class RegistrationServiceSessionRefreshClient implements SessionRefreshClient {
  const RegistrationServiceSessionRefreshClient({RegistrationService? service})
      : _service = service ?? RegistrationService();

  final RegistrationService _service;

  @override
  Future<RefreshSessionResponse?> refresh(String refreshToken) {
    return _service.refreshSession(refreshToken: refreshToken);
  }
}

class SessionRefreshException implements Exception {
  const SessionRefreshException(this.message);

  final String message;

  @override
  String toString() => 'SessionRefreshException: $message';
}

class SessionRefresher {
  SessionRefresher({
    SessionRefreshClient? client,
    TokenExpiryEvaluator? tokenExpiryEvaluator,
    Logger? logger,
  })  : _client = client ?? const RegistrationServiceSessionRefreshClient(),
        _tokenExpiryEvaluator = tokenExpiryEvaluator ?? JwtDecoder.isExpired,
        _log = logger ?? Logger('SessionRefresher');

  final SessionRefreshClient _client;
  final TokenExpiryEvaluator _tokenExpiryEvaluator;
  final Logger _log;

  Future<User?> refreshIfExpired(User user) async {
    var isExpired = true;
    try {
      isExpired = _tokenExpiryEvaluator(user.accessToken);
    } catch (error, stackTrace) {
      _log.warning('Failed to evaluate token expiry', error, stackTrace);
    }

    if (!isExpired) {
      return null;
    }

    final refreshed = await _client.refresh(user.refreshToken);
    if (refreshed == null) {
      throw const SessionRefreshException('Unable to refresh session with server');
    }

    return user.copyWith(
      accessToken: refreshed.accessToken,
      refreshToken: refreshed.refreshToken,
    );
  }
}

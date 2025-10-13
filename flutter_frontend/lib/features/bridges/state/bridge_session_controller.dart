import 'package:flutter/foundation.dart';
import 'package:messngr/features/bridges/models/bridge_auth_session.dart';
import 'package:messngr/services/api/bridge_api.dart';
import 'package:messngr/services/api/chat_api.dart';

/// Handles lifecycle operations for a single bridge authentication session.
class BridgeSessionController extends ChangeNotifier {
  BridgeSessionController({
    required AccountIdentity identity,
    required BridgeApi api,
    required BridgeAuthSession initialSession,
    required this.bridgeId,
  })  : _identity = identity,
        _api = api,
        _session = initialSession;

  final AccountIdentity _identity;
  final BridgeApi _api;
  BridgeAuthSession _session;

  final String bridgeId;

  bool _busy = false;
  Object? _error;

  BridgeAuthSession get session => _session;
  bool get isBusy => _busy;
  Object? get error => _error;

  Uri? get authorizationUrl {
    final path = _session.authorizationPath;
    if (path.isEmpty) return null;
    return _api.resolveAuthorizationUrl(path);
  }

  Uri? get callbackUrl {
    final path = _session.callbackPath;
    if (path.isEmpty) return null;
    return _api.resolveCallbackUrl(path);
  }

  Future<void> refresh() async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _session = await _api.fetchSession(
        current: _identity,
        sessionId: _session.id,
      );
    } catch (err) {
      _error = err;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> submitCredentials(Map<String, dynamic> credentials) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _session = await _api.submitCredentials(
        current: _identity,
        bridgeId: bridgeId,
        sessionId: _session.id,
        credentials: credentials,
      );
    } catch (err) {
      _error = err;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> unlink() async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _api.unlink(
        current: _identity,
        bridgeId: bridgeId,
      );
      await refresh();
    } catch (err) {
      _error = err;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}

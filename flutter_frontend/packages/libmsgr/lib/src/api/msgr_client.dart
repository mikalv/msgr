import '../realtime/channel_client.dart';
import 'models.dart';
import 'msgr_api_client.dart';

/// Unified Msgr client combining REST API + real-time Phoenix channels.
///
/// This is the main entry point for all server communication from any Dart
/// client (Flutter app, CLI tool, bot, TUI).
///
/// Usage:
/// ```dart
/// final client = MsgrClient(baseUrl: 'https://dev.msgr.no');
///
/// // Authenticate
/// final challenge = await client.api.requestChallenge('user@example.com');
/// final session = await client.api.verifyCode(challenge.id, code);
/// client.setSession(session);
///
/// // Connect realtime
/// await client.connectRealtime();
/// await client.realtime.join('channel:lobby');
/// ```
class MsgrClient {
  MsgrClient({required this.baseUrl}) {
    api = MsgrApiClient(baseUrl: baseUrl);
  }

  final String baseUrl;
  late final MsgrApiClient api;
  MsgrRealtimeClient? _realtime;

  /// The realtime client. Only available after [connectRealtime].
  MsgrRealtimeClient get realtime {
    if (_realtime == null) {
      throw StateError(
        'Realtime client not connected. Call connectRealtime() first.',
      );
    }
    return _realtime!;
  }

  /// Whether the realtime client is connected.
  bool get isRealtimeConnected => _realtime?.isConnected ?? false;

  String? get accountId => api.accountId;
  String? get profileId => api.profileId;

  /// Update the API client with session credentials obtained from login.
  void setSession(SessionResult session) {
    api.accountId = session.accountId;
    api.profileId = session.profileId;
  }

  /// Set account and profile IDs directly (e.g. when restoring from storage).
  void setCredentials({required String accountId, required String profileId}) {
    api.accountId = accountId;
    api.profileId = profileId;
  }

  /// Connect the Phoenix WebSocket for real-time events.
  ///
  /// Requires [accountId] and [profileId] to be set (via [setSession] or
  /// [setCredentials]).
  Future<void> connectRealtime({String? sessionId}) async {
    if (api.accountId == null || api.profileId == null) {
      throw StateError(
        'Cannot connect realtime without accountId and profileId. '
        'Call setSession() or setCredentials() first.',
      );
    }

    final wsUrl = baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    _realtime = MsgrRealtimeClient(
      wsUrl: '$wsUrl/socket/websocket',
      accountId: api.accountId!,
      profileId: api.profileId!,
      sessionId: sessionId,
    );

    await _realtime!.connect();
  }

  /// Disconnect the real-time client.
  void disconnectRealtime() {
    _realtime?.disconnect();
    _realtime = null;
  }

  /// Disconnect everything.
  void dispose() {
    disconnectRealtime();
  }
}

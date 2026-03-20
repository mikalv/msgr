import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:core/providers/auth_provider.dart';
import 'package:core/providers/team_provider.dart';
import 'package:core/providers/msgr_client_provider.dart';

/// WebSocket connection state
class WebSocketState {
  final bool isConnected;
  final bool isConnecting;
  final Exception? error;

  const WebSocketState({
    this.isConnected = false,
    this.isConnecting = false,
    this.error,
  });

  WebSocketState copyWith({
    bool? isConnected,
    bool? isConnecting,
    Exception? error,
  }) {
    return WebSocketState(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      error: error ?? this.error,
    );
  }
}

/// WebSocket notifier class -- now uses MsgrClient.realtime from libmsgr.
class WebSocketNotifier extends StateNotifier<WebSocketState> {
  WebSocketNotifier(this._ref) : super(const WebSocketState());

  final Ref _ref;

  /// Connect to WebSocket when team is selected.
  ///
  /// This method supports two paths:
  /// 1. Legacy path (via LibMsgr singleton + MsgrConnection for bootstrapped apps)
  /// 2. New path (via MsgrClient.realtime for header-auth apps)
  Future<void> connect() async {
    final authState = _ref.read(authProvider);
    final currentTeam = authState.currentTeam;
    final teamAccessToken = authState.teamAccessToken;
    final currentUser = authState.currentUser;

    // Try legacy path first (for apps using full LibMsgr bootstrap).
    if (currentTeam != null && teamAccessToken != null && currentUser != null) {
      await _connectLegacy(currentTeam, teamAccessToken, currentUser);
      return;
    }

    // New path: use MsgrClient from libmsgr.
    await _connectNew();
  }

  Future<void> _connectLegacy(
      Team currentTeam, String teamAccessToken, User currentUser) async {
    state = state.copyWith(isConnecting: true);
    try {
      if (!LibMsgr().hasBootstrapped) {
        await LibMsgr().bootstrapLibrary();
      }

      final connected = await LibMsgr().connectWebsocket(
        currentUser.id,
        currentTeam.name,
        teamAccessToken,
        _handleWebSocketEvent,
      );

      if (connected) {
        await _ref.read(teamProvider.notifier).loadTeamData(currentTeam.name);
        state = state.copyWith(isConnected: true, isConnecting: false);
      } else {
        throw Exception('Failed to connect to WebSocket');
      }
    } catch (e) {
      state = state.copyWith(isConnecting: false, error: e as Exception);
      rethrow;
    }
  }

  Future<void> _connectNew() async {
    state = state.copyWith(isConnecting: true);
    try {
      final client = _ref.read(msgrClientProvider);
      if (client.accountId == null || client.profileId == null) {
        throw Exception('Not authenticated -- cannot connect WebSocket');
      }

      await client.connectRealtime();

      client.realtime.onDisconnect = () {
        if (mounted) {
          state = state.copyWith(isConnected: false);
        }
      };

      client.realtime.onReconnect = () {
        if (mounted) {
          state = state.copyWith(isConnected: true);
        }
      };

      state = state.copyWith(isConnected: true, isConnecting: false);
    } catch (e) {
      state = state.copyWith(isConnecting: false, error: e as Exception);
      rethrow;
    }
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    try {
      final client = _ref.read(msgrClientProvider);
      client.disconnectRealtime();
    } catch (_) {}
    state = const WebSocketState();
  }

  /// Send a message to a conversation or channel
  void sendMessage({
    required String content,
    String? conversationId,
    String? channelId,
  }) {
    // Try the new MsgrClient path first.
    final client = _ref.read(msgrClientProvider);
    if (client.isRealtimeConnected) {
      final destTopic = conversationId != null
          ? 'conversation:$conversationId'
          : 'channel:$channelId';
      client.realtime
          .push(destTopic, 'create:msg', {'content': content}).catchError(
              (e) {
        // Fallback: try legacy MsgrConnection
        _sendViaLegacy(content, conversationId, channelId);
      });
      return;
    }

    _sendViaLegacy(content, conversationId, channelId);
  }

  void _sendViaLegacy(
      String content, String? conversationId, String? channelId) {
    final connection = LibMsgr().getWebsocketConnection();
    if (connection == null) {
      throw Exception('Not connected to WebSocket');
    }

    final currentProfile = _ref.read(currentProfileProvider);
    if (currentProfile == null) {
      throw Exception('No current profile');
    }

    final message = MMessage(
      content: content,
      fromProfileID: currentProfile.id,
      conversationID: conversationId,
      channelID: channelId,
    );

    final destId = conversationId ?? channelId;
    if (destId != null) {
      connection.sendMessage(destId, message);
    }
  }

  /// Send typing indicator
  void sendTypingIndicator({
    String? conversationId,
    String? channelId,
  }) {
    // TODO: Implement via Phoenix channel push
  }

  /// Handle WebSocket events (Redux dispatch callback -- legacy path)
  void _handleWebSocketEvent(dynamic event) {
    // Left empty: repositories handle updates via Redux actions.
  }
}

/// WebSocket state provider
final webSocketProvider =
    StateNotifierProvider<WebSocketNotifier, WebSocketState>((ref) {
  return WebSocketNotifier(ref);
});

/// Convenience provider for connection status
final isWebSocketConnectedProvider = Provider<bool>((ref) {
  return ref.watch(webSocketProvider).isConnected;
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:core/providers/auth_provider.dart';
import 'package:core/providers/team_provider.dart';

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

/// WebSocket notifier class
class WebSocketNotifier extends StateNotifier<WebSocketState> {
  WebSocketNotifier(this._ref) : super(const WebSocketState());

  final Ref _ref;
  MsgrConnection? _connection;

  /// Connect to WebSocket when team is selected
  Future<void> connect() async {
    final authState = _ref.read(authProvider);
    final currentTeam = authState.currentTeam;
    final teamAccessToken = authState.teamAccessToken;
    final currentUser = authState.currentUser;

    if (currentTeam == null || teamAccessToken == null || currentUser == null) {
      throw Exception('Missing team, token, or user for WebSocket connection');
    }

    state = state.copyWith(isConnecting: true);

    try {
      // Ensure LibMsgr is bootstrapped
      if (!LibMsgr().hasBootstrapped) {
        await LibMsgr().bootstrapLibrary();
      }

      // Connect to WebSocket
      final connected = await LibMsgr().connectWebsocket(
        currentUser.id,
        currentTeam.name,
        teamAccessToken,
        _handleWebSocketEvent,
      );

      if (connected) {
        _connection = LibMsgr().getWebsocketConnection();

        // Load team data into team_provider
        await _ref.read(teamProvider.notifier).loadTeamData(currentTeam.name);

        state = state.copyWith(
          isConnected: true,
          isConnecting: false,
        );
      } else {
        throw Exception('Failed to connect to WebSocket');
      }
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        error: e as Exception,
      );
      rethrow;
    }
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    _connection = null;
    state = const WebSocketState();
  }

  /// Send a message to a conversation or room
  void sendMessage({
    required String content,
    String? conversationId,
    String? roomId,
  }) {
    if (_connection == null) {
      throw Exception('Not connected to WebSocket');
    }

    final currentProfile = _ref.read(currentProfileProvider);
    if (currentProfile == null) {
      throw Exception('No current profile');
    }

    // Create message object
    final message = MMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      senderID: currentProfile.id,
      conversationID: conversationId,
      roomID: roomId,
    );

    // Send message via Phoenix channel
    final destId = conversationId ?? roomId;
    if (destId != null) {
      _connection!.sendMessage(destId, message);
    }
  }

  /// Send typing indicator
  /// Note: Typing indicators are typically handled by Phoenix presence
  /// and may need to be implemented via channel events
  void sendTypingIndicator({
    String? conversationId,
    String? roomId,
  }) {
    if (_connection == null) {
      throw Exception('Not connected to WebSocket');
    }

    // TODO: Implement typing indicator via Phoenix channel push
    // This will likely need to be a custom event like 'typing:start'
    // For now, this is a placeholder
  }

  /// Handle WebSocket events (Redux dispatch callback)
  void _handleWebSocketEvent(dynamic event) {
    // This callback is used by LibMsgr to dispatch Redux actions
    // For now, we can leave it empty since repositories handle updates
    // In the future, this could be used to emit Riverpod events
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

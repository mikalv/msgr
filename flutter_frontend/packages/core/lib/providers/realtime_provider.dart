import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:logging/logging.dart';

import 'auth_state_provider.dart';
import 'channel_list_provider.dart';
import 'messages_provider.dart';
import 'models.dart';
import 'msgr_client_provider.dart';
import 'notification_provider.dart';
import 'settings_provider.dart';
import 'team_list_provider.dart';
import 'thread_provider.dart';
import 'typing_provider.dart';

// ---------------------------------------------------------------------------
// RealtimeState
// ---------------------------------------------------------------------------

class RealtimeState {
  const RealtimeState({
    this.isConnected = false,
    this.isConnecting = false,
    this.error,
  });

  final bool isConnected;
  final bool isConnecting;
  final Object? error;

  RealtimeState copyWith({
    bool? isConnected,
    bool? isConnecting,
    Object? error,
  }) {
    return RealtimeState(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      error: error,
    );
  }
}

// ---------------------------------------------------------------------------
// RealtimeNotifier
// ---------------------------------------------------------------------------

/// Manages Phoenix WebSocket lifecycle and routes incoming events to the
/// appropriate Riverpod providers.
///
/// Connects on login, disconnects on logout. Subscribes to team and channel
/// topics automatically when the selected team/channel changes.
class RealtimeNotifier extends StateNotifier<RealtimeState> {
  RealtimeNotifier(this._ref) : super(const RealtimeState());

  final Ref _ref;
  final _log = Logger('RealtimeNotifier');

  String? _currentTeamSlug;
  String? _currentChannelId;
  Timer? _reconnectTimer;

  /// Connect the WebSocket using credentials from the MsgrClient.
  Future<void> connect() async {
    final client = _ref.read(msgrClientProvider);
    if (client.accountId == null || client.profileId == null) {
      _log.warning('Cannot connect realtime: not authenticated');
      return;
    }

    if (client.isRealtimeConnected) {
      state = state.copyWith(isConnected: true, isConnecting: false);
      return;
    }

    state = state.copyWith(isConnecting: true, error: null);
    try {
      await client.connectRealtime();

      client.realtime.onEvent = _handleEvent;

      client.realtime.onDisconnect = () {
        if (mounted) {
          _log.info('WebSocket disconnected');
          state = state.copyWith(isConnected: false);
          _scheduleReconnect();
        }
      };

      client.realtime.onReconnect = () {
        if (mounted) {
          _log.info('WebSocket reconnected');
          _reconnectTimer?.cancel();
          _reconnectTimer = null;
          state = state.copyWith(isConnected: true);
          _rejoinTopics();
        }
      };

      state = state.copyWith(isConnected: true, isConnecting: false);

      // Auto-join current team/channel after successful connect
      final selectedTeam = _ref.read(selectedTeamProvider);
      if (selectedTeam != null) {
        await joinTeam(selectedTeam.slug);
      }
      final selectedChannel = _ref.read(selectedChannelProvider);
      if (selectedChannel != null) {
        await joinChannel(selectedChannel.id);
      }
    } catch (e) {
      _log.warning('WebSocket connect failed: $e');
      state = state.copyWith(isConnecting: false, error: e);
      _scheduleReconnect();
    }
  }

  /// Disconnect and clean up.
  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    try {
      final client = _ref.read(msgrClientProvider);
      client.disconnectRealtime();
    } catch (_) {}

    _currentTeamSlug = null;
    _currentChannelId = null;
    state = const RealtimeState();
  }

  /// Join team topics when the selected team changes.
  Future<void> joinTeam(String teamSlug) async {
    final client = _ref.read(msgrClientProvider);
    _log.info('joinTeam($teamSlug) called, isRealtimeConnected=${client.isRealtimeConnected}');
    if (!client.isRealtimeConnected) return;

    // Leave previous team topics
    if (_currentTeamSlug != null && _currentTeamSlug != teamSlug) {
      try {
        await client.realtime.leave('team:$_currentTeamSlug');
        await client.realtime.leave('presence:$_currentTeamSlug');
      } catch (_) {}
    }

    _currentTeamSlug = teamSlug;

    try {
      await client.realtime.join('team:$teamSlug');
      await client.realtime.join('presence:$teamSlug');
      _log.info('Joined team topics: team:$teamSlug, presence:$teamSlug');
    } catch (e) {
      _log.warning('Failed to join team topics: $e');
    }
  }

  /// Join a channel topic. Leaves the previous channel topic automatically.
  Future<void> joinChannel(String channelId) async {
    final client = _ref.read(msgrClientProvider);
    _log.info('joinChannel($channelId) called, isRealtimeConnected=${client.isRealtimeConnected}');
    if (!client.isRealtimeConnected) return;

    // Leave previous channel topic
    if (_currentChannelId != null && _currentChannelId != channelId) {
      try {
        await client.realtime.leave('channel:$_currentChannelId');
      } catch (_) {}
    }

    _currentChannelId = channelId;

    try {
      // Pass team_slug so the backend can resolve the tenant prefix
      // when connected without a JWT token.
      await client.realtime.join(
        'channel:$channelId',
        payload: {
          if (_currentTeamSlug != null) 'team_slug': _currentTeamSlug,
        },
      );
      _log.info('Joined channel topic: channel:$channelId');
    } catch (e) {
      _log.warning('Failed to join channel topic: $e');
    }
  }

  /// Send a message via Phoenix Channel push with REST fallback.
  ///
  /// Returns true if push succeeded, false if fell back to REST.
  Future<bool> sendMessageViaChannel(
    String channelId,
    dynamic content, {
    List<String>? mediaRefs,
  }) async {
    final client = _ref.read(msgrClientProvider);
    if (!client.isRealtimeConnected ||
        client.realtime.getChannel('channel:$channelId') == null) {
      return false; // Caller should use REST fallback
    }

    try {
      // content can be a plain String or a Map with 'text' + 'mentions'.
      final contentPayload = content is String ? {'text': content} : content;
      final reply = await client.realtime.push(
        'channel:$channelId',
        'new:message',
        {
          'content': contentPayload,
          if (mediaRefs != null && mediaRefs.isNotEmpty)
            'media_refs': mediaRefs,
        },
      );
      _log.fine('Message sent via channel push: $reply');
      return true;
    } catch (e) {
      _log.warning('Channel push failed, caller should use REST: $e');
      return false;
    }
  }

  /// Toggle a reaction via Phoenix Channel push.
  ///
  /// Returns true if push succeeded, false if caller should use REST fallback.
  Future<bool> toggleReactionViaChannel(
    String channelId,
    String messageId,
    String emoji,
  ) async {
    final client = _ref.read(msgrClientProvider);
    if (!client.isRealtimeConnected ||
        client.realtime.getChannel('channel:$channelId') == null) {
      return false;
    }

    try {
      await client.realtime.push(
        'channel:$channelId',
        'toggle:reaction',
        {
          'message_id': messageId,
          'emoji': emoji,
        },
      );
      return true;
    } catch (e) {
      _log.warning('Channel reaction push failed: $e');
      return false;
    }
  }

  /// Send typing indicator via channel push.
  ///
  /// Respects the user's typing indicators privacy setting.
  void sendTypingStart(String channelId) {
    final sendTyping = _ref.read(sendTypingIndicatorsProvider);
    if (!sendTyping) return;

    final client = _ref.read(msgrClientProvider);
    if (!client.isRealtimeConnected) return;

    try {
      client.realtime.push('channel:$channelId', 'typing:start', {});
    } catch (_) {}
  }

  void sendTypingStop(String channelId) {
    final sendTyping = _ref.read(sendTypingIndicatorsProvider);
    if (!sendTyping) return;

    final client = _ref.read(msgrClientProvider);
    if (!client.isRealtimeConnected) return;

    try {
      client.realtime.push('channel:$channelId', 'typing:stop', {});
    } catch (_) {}
  }

  // ── Event routing ──────────────────────────────────────────────

  void _handleEvent(
      String topic, String event, Map<String, dynamic> payload) {
    _log.fine('Event: $topic / $event');

    if (topic.startsWith('channel:')) {
      _handleChannelEvent(topic, event, payload);
    } else if (topic.startsWith('team:')) {
      _handleTeamEvent(topic, event, payload);
    } else if (topic.startsWith('presence:')) {
      _handlePresenceEvent(topic, event, payload);
    }
  }

  void _handleChannelEvent(
      String topic, String event, Map<String, dynamic> payload) {
    final channelId = topic.replaceFirst('channel:', '');

    switch (event) {
      case 'new:message':
        _onNewMessage(channelId, payload);
      case 'new:thread_reply':
        final msgData = payload['message'] as Map<String, dynamic>? ?? payload;
        _onNewThreadReply(channelId, msgData);
      case 'typing:update' || 'typing_started' || 'typing_stopped':
        _onTypingUpdate(channelId, payload, event);
      case 'message:edited':
        _onMessageEdited(channelId, payload);
      case 'reaction:updated':
        _onReactionUpdated(channelId, payload);
      case 'read_cursor:updated':
        _log.fine('Read cursor updated for ${payload['profile_id']}');
      case 'phx_reply' || 'phx_error' || 'phx_close':
        break; // Phoenix internal events
      default:
        _log.fine('Unhandled channel event: $event');
    }
  }

  void _handleTeamEvent(
      String topic, String event, Map<String, dynamic> payload) {
    switch (event) {
      case 'new:channel':
        _onNewChannel(payload);
      case 'channel:updated':
        _log.fine('Channel updated: ${payload['id']}');
        // Refresh channel list
        _ref.read(channelListProvider.notifier).refresh();
      case 'member:joined':
        _log.fine('Member joined: ${payload['profile_id']}');
      case 'member:left':
        _log.fine('Member left: ${payload['profile_id']}');
      case 'phx_reply' || 'phx_error' || 'phx_close':
        break;
      default:
        _log.fine('Unhandled team event: $event');
    }
  }

  void _handlePresenceEvent(
      String topic, String event, Map<String, dynamic> payload) {
    // Presence events are handled by phoenix_socket's Presence module
    // and delivered via the onPresence callback. For now just log.
    _log.fine('Presence event: $event');
  }

  void _onNewMessage(String channelId, Map<String, dynamic> data) {
    final auth = _ref.read(simpleAuthProvider);
    final senderProfileId = data['sender_profile_id']?.toString() ?? '';

    // Skip messages we sent ourselves (already handled by optimistic insert)
    if (senderProfileId == auth.profileId) return;

    final senderProfile =
        data['sender_profile'] as Map<String, dynamic>? ?? {};

    final message = SlackMessage(
      id: data['id']?.toString() ?? '',
      channelId: channelId,
      senderProfileId: senderProfileId,
      senderName: senderProfile['display_name']?.toString() ??
          data['sender_name']?.toString() ??
          'Ukjent',
      content: _extractContent(data['content']),
      insertedAt:
          DateTime.tryParse(data['inserted_at']?.toString() ?? '') ??
              DateTime.now(),
      threadParentId: data['thread_parent_id'] as String?,
      mediaRefs: (data['media_refs'] as List?)
              ?.map((r) => r.toString())
              .toList() ??
          [],
      status: MessageStatus.sent,
    );

    // Only merge if this is the currently viewed channel
    final selectedChannel = _ref.read(selectedChannelProvider);
    if (selectedChannel != null && selectedChannel.id == channelId) {
      _ref.read(channelMessagesProvider.notifier).mergeIncoming(message);
    }
  }

  void _onMessageEdited(String channelId, Map<String, dynamic> data) {
    final selectedChannel = _ref.read(selectedChannelProvider);
    if (selectedChannel == null || selectedChannel.id != channelId) return;

    final auth = _ref.read(simpleAuthProvider);
    final messageId = data['id']?.toString() ?? '';
    final newContent = _extractContent(data['content']);
    final editedAt = DateTime.tryParse(data['edited_at']?.toString() ?? '');

    _ref.read(channelMessagesProvider.notifier).updateMessage(
      messageId,
      content: newContent,
      editedAt: editedAt,
    );
  }

  void _onNewThreadReply(String channelId, Map<String, dynamic> data) {
    final auth = _ref.read(simpleAuthProvider);
    final senderProfileId = data['sender_profile_id']?.toString() ?? '';

    // Skip messages we sent ourselves (already handled by optimistic insert)
    if (senderProfileId == auth.profileId) return;

    final senderProfile =
        data['sender_profile'] as Map<String, dynamic>? ?? {};

    final reply = SlackMessage(
      id: data['id']?.toString() ?? '',
      channelId: channelId,
      senderProfileId: senderProfileId,
      senderName: senderProfile['display_name']?.toString() ??
          data['sender_name']?.toString() ??
          'Ukjent',
      content: _extractContent(data['content']),
      insertedAt:
          DateTime.tryParse(data['inserted_at']?.toString() ?? '') ??
              DateTime.now(),
      threadParentId: data['thread_parent_id'] as String?,
      status: MessageStatus.sent,
    );

    // Forward to thread provider if this thread is currently open
    _ref.read(threadMessagesProvider.notifier).mergeIncomingReply(reply);

    // Also increment the reply count on the parent message in the channel list
    final parentId = reply.threadParentId;
    if (parentId != null) {
      final selectedChannel = _ref.read(selectedChannelProvider);
      if (selectedChannel != null && selectedChannel.id == channelId) {
        final messagesState = _ref.read(channelMessagesProvider);
        final idx =
            messagesState.messages.indexWhere((m) => m.id == parentId);
        if (idx >= 0) {
          final msg = messagesState.messages[idx];
          final updated =
              msg.copyWith(threadReplyCount: msg.threadReplyCount + 1);
          _ref.read(channelMessagesProvider.notifier).mergeIncoming(updated);
        }
      }
    }

    // Show desktop notification for thread replies
    if (Platform.isMacOS) {
      _showNotificationForMessage(reply, channelId, data);
    }
  }

  void _onNewChannel(Map<String, dynamic> data) {
    // Refresh the channel list from the server to get the full channel data
    _ref.read(channelListProvider.notifier).refresh();
  }

  void _onReactionUpdated(String channelId, Map<String, dynamic> data) {
    final messageId = data['message_id']?.toString();
    if (messageId == null) return;

    final auth = _ref.read(simpleAuthProvider);
    final rawReactions = data['reactions'];
    if (rawReactions is! List) return;

    final reactions = <MessageReaction>[];
    for (final r in rawReactions) {
      if (r is Map<String, dynamic>) {
        reactions.add(
          MessageReaction.fromJson(r, currentProfileId: auth.profileId),
        );
      }
    }

    final selectedChannel = _ref.read(selectedChannelProvider);
    if (selectedChannel != null && selectedChannel.id == channelId) {
      _ref
          .read(channelMessagesProvider.notifier)
          .updateReactions(messageId, reactions);
    }
  }

  void _onTypingUpdate(String channelId, Map<String, dynamic> data, String event) {
    final profileId = data['profile_id']?.toString() ?? '';
    final profileName = data['profile_name']?.toString() ?? profileId;
    final auth = _ref.read(simpleAuthProvider);

    // Don't show our own typing indicator
    if (profileId == auth.profileId) return;

    final isTyping = event == 'typing_started' || (data['is_typing'] as bool? ?? false);

    final typingNotifier = _ref.read(typingIndicatorsProvider.notifier);
    if (isTyping) {
      typingNotifier.setTyping(channelId, profileName);
    } else {
      typingNotifier.stopTyping(channelId, profileName);
    }
  }

  // ── Desktop notifications ─────────────────────────────────────

  void _showNotificationForMessage(
    SlackMessage message,
    String channelId,
    Map<String, dynamic> rawData,
  ) {
    // Respect the user's desktop notification preference
    final desktopEnabled = _ref.read(desktopNotificationsEnabledProvider);
    if (!desktopEnabled) return;

    final notifService = _ref.read(desktopNotificationServiceProvider);

    // Check if message contains a mention of the current user
    final auth = _ref.read(simpleAuthProvider);
    final mentions = rawData['content'] is Map
        ? (rawData['content']['mentions'] as List?)
        : null;
    final isMentioned = mentions != null &&
        mentions.any((m) =>
            m is Map<String, dynamic> &&
            m['profile_id']?.toString() == auth.profileId);

    // Always notify for @mentions, even when focused
    if (isMentioned) {
      final channelName = _resolveChannelName(channelId);
      notifService.showMentionNotification(
        channelName: channelName,
        senderName: message.senderName,
        body: message.content,
        channelId: channelId,
      );
      return;
    }

    // Don't notify when app is focused
    if (notifService.isAppFocused) return;

    // Build notification title based on channel type
    final title = _buildNotificationTitle(channelId, message.senderName);

    notifService.showMessageNotification(
      title: title,
      body: '${message.senderName}: ${message.content}',
      channelId: channelId,
    );
  }

  /// Resolve a channel name from the channel list state.
  String _resolveChannelName(String channelId) {
    try {
      final channelsState = _ref.read(channelListProvider);
      final channel = channelsState.channels
          .where((c) => c.id == channelId)
          .firstOrNull;
      if (channel != null) return channel.name;
    } catch (_) {}
    return channelId;
  }

  /// Build a notification title like "#general" or "DM: Alice".
  String _buildNotificationTitle(String channelId, String senderName) {
    try {
      final channelsState = _ref.read(channelListProvider);
      final channel = channelsState.channels
          .where((c) => c.id == channelId)
          .firstOrNull;
      if (channel != null) {
        if (channel.kind == ChannelKind.dm ||
            channel.kind == ChannelKind.groupDm) {
          return 'DM: $senderName';
        }
        return '#${channel.name}';
      }
    } catch (_) {}
    return '#$channelId';
  }

  // ── Reconnection ───────────────────────────────────────────────

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !state.isConnected && !state.isConnecting) {
        _log.info('Attempting reconnect...');
        connect();
      }
    });
  }

  void _rejoinTopics() {
    // Re-join all active topics after reconnect
    if (_currentTeamSlug != null) {
      joinTeam(_currentTeamSlug!);
    }
    if (_currentChannelId != null) {
      joinChannel(_currentChannelId!);
    }

    // Refresh current channel messages to catch anything missed
    final selectedChannel = _ref.read(selectedChannelProvider);
    if (selectedChannel != null) {
      _ref
          .read(channelMessagesProvider.notifier)
          .refresh(selectedChannel.id);
    }
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final realtimeProvider =
    StateNotifierProvider<RealtimeNotifier, RealtimeState>((ref) {
  final notifier = RealtimeNotifier(ref);

  // Auto-connect when auth state becomes logged in.
  // connect() will auto-join the current team/channel after success.
  final auth = ref.watch(simpleAuthProvider);
  if (auth.isLoggedIn && !auth.isLoading) {
    Future.microtask(() => notifier.connect());
  }

  // Auto-join team topic when selected team changes AFTER already connected.
  final selectedTeam = ref.watch(selectedTeamProvider);
  if (selectedTeam != null) {
    Future.microtask(() {
      final client = ref.read(msgrClientProvider);
      if (client.isRealtimeConnected) {
        notifier.joinTeam(selectedTeam.slug);
      }
    });
  }

  // Auto-join channel topic when selected channel changes AFTER already connected.
  final selectedChannel = ref.watch(selectedChannelProvider);
  if (selectedChannel != null) {
    Future.microtask(() {
      final client = ref.read(msgrClientProvider);
      if (client.isRealtimeConnected) {
        notifier.joinChannel(selectedChannel.id);
      }
    });
  }

  ref.onDispose(() => notifier.disconnect());
  return notifier;
});

/// Whether the realtime WebSocket is connected.
final isRealtimeConnectedProvider = Provider<bool>((ref) {
  return ref.watch(realtimeProvider).isConnected;
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Extract text from content field -- handles both String and Map (JSONB).
String _extractContent(dynamic content) {
  if (content is String) return content;
  if (content is Map) return content['text']?.toString() ?? content.toString();
  return content?.toString() ?? '';
}

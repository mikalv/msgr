import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:messngr/features/chat/models/chat_message.dart';
import 'package:messngr/features/chat/models/chat_thread.dart';
import 'package:messngr/services/api/chat_api.dart';
import 'package:messngr/services/api/chat_socket.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatViewModel extends ChangeNotifier {
  ChatViewModel({ChatApi? api, ChatRealtime? realtime})
      : _api = api ?? ChatApi(),
        _realtime = realtime ?? ChatSocket();

  final ChatApi _api;
  final ChatRealtime _realtime;
  final _random = Random();

  static const _accountIdKey = 'chat.account.id';
  static const _profileIdKey = 'chat.profile.id';
  static const _peerProfileIdKey = 'chat.peer.profile.id';

  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  List<ChatMessage> _messages = const [];
  ChatThread? _thread;
  AccountIdentity? _identity;
  String? _peerProfileId;
  StreamSubscription<ChatMessage>? _realtimeSubscription;
  bool _realtimeConnected = false;

  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  List<ChatMessage> get messages => _messages;
  ChatThread? get thread => _thread;
  AccountIdentity? get identity => _identity;

  Future<void> bootstrap() async {
    if (_isLoading) return;
    _setLoading(true);
    _error = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await _ensureIdentities(prefs);
      await _ensureConversation();
      await fetchMessages();
      await _connectRealtime();
    } catch (error, stack) {
      debugPrint('Failed to bootstrap chat: $error\n$stack');
      _setError('Klarte ikke å laste chatten.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchMessages() async {
    if (_identity == null || _thread == null) return;

    try {
      final messages = await _api.fetchMessages(
        current: _identity!,
        conversationId: _thread!.id,
      );
      _messages = messages;
      notifyListeners();
    } on ApiException catch (error) {
      debugPrint('fetchMessages failed: $error');
      _setError('Kunne ikke hente meldinger (${error.statusCode}).');
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _identity == null || _thread == null) {
      return;
    }

    final tempId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();
    final localMessage = ChatMessage.text(
      id: tempId,
      body: trimmed,
      profileId: _identity!.profileId,
      profileName: 'Deg',
      profileMode: 'private',
      status: 'sending',
      sentAt: now,
      insertedAt: now,
      isLocal: true,
    );

    _messages = [..._messages, localMessage];
    _error = null;
    _isSending = true;
    notifyListeners();

    try {
      final persisted = await _sendOverPreferredChannel(trimmed);
      _mergeMessage(persisted, replaceTempId: tempId);
    } on ChatSocketException catch (error, stack) {
      debugPrint('Realtime send failed: $error\n$stack');

      try {
        final persisted = await _api.sendMessage(
          current: _identity!,
          conversationId: _thread!.id,
          body: trimmed,
        );
        _mergeMessage(persisted, replaceTempId: tempId);
      } on ApiException catch (fallbackError) {
        debugPrint('Fallback send failed: $fallbackError');
        _messages =
            _messages.where((message) => message.id != tempId).toList();
        _setError('Kunne ikke sende melding (${fallbackError.statusCode}).');
      }
    } on ApiException catch (error) {
      debugPrint('sendMessage failed: $error');
      _messages = _messages.where((message) => message.id != tempId).toList();
      _setError('Kunne ikke sende melding (${error.statusCode}).');
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> _ensureIdentities(SharedPreferences prefs) async {
    final accountId = prefs.getString(_accountIdKey);
    final profileId = prefs.getString(_profileIdKey);
    final peerProfileId = prefs.getString(_peerProfileIdKey);

    if (accountId != null && profileId != null && peerProfileId != null) {
      _identity = AccountIdentity(accountId: accountId, profileId: profileId);
      _peerProfileId = peerProfileId;
      return;
    }

    final mainIdentity =
        await _api.createAccount('Demo ${_suffix()}', email: _debugEmail('demo'));
    final buddyIdentity =
        await _api.createAccount('Companion ${_suffix()}', email: _debugEmail('buddy'));

    await prefs.setString(_accountIdKey, mainIdentity.accountId);
    await prefs.setString(_profileIdKey, mainIdentity.profileId);
    await prefs.setString(_peerProfileIdKey, buddyIdentity.profileId);

    _identity = mainIdentity;
    _peerProfileId = buddyIdentity.profileId;
  }

  Future<void> _ensureConversation() async {
    if (_identity == null || _peerProfileId == null) return;

    _thread = await _api.ensureDirectConversation(
      current: _identity!,
      targetProfileId: _peerProfileId!,
    );
  }

  Future<void> _connectRealtime() async {
    if (_identity == null || _thread == null) return;

    try {
      await _realtimeSubscription?.cancel();
      await _realtime.connect(
        identity: _identity!,
        conversationId: _thread!.id,
      );

      _realtimeConnected = true;
      _realtimeSubscription = _realtime.messages.listen(
        (message) => _mergeMessage(message),
        onError: (error) {
          debugPrint('Realtime stream error: $error');
        },
      );
    } on ChatSocketException catch (error, stack) {
      debugPrint('Failed to connect realtime: $error\n$stack');
      _realtimeConnected = false;
    } catch (error, stack) {
      debugPrint('Unexpected realtime error: $error\n$stack');
      _realtimeConnected = false;
    }
  }

  Future<ChatMessage> _sendOverPreferredChannel(String body) async {
    if (_realtimeConnected && _realtime.isConnected) {
      return _realtime.send(body);
    }

    return _api.sendMessage(
      current: _identity!,
      conversationId: _thread!.id,
      body: body,
    );
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  String _suffix() => (_random.nextInt(9000) + 1000).toString();

  String _debugEmail(String label) => '$label-${DateTime.now().millisecondsSinceEpoch}@msgr.dev';

  void _mergeMessage(ChatMessage incoming, {String? replaceTempId}) {
    List<ChatMessage> updated;

    final existingIndex =
        _messages.indexWhere((message) => message.id == incoming.id);

    if (existingIndex >= 0) {
      updated = [
        for (final message in _messages)
          if (message.id == incoming.id) incoming else message,
      ];
    } else if (replaceTempId != null) {
      final tempIndex =
          _messages.indexWhere((message) => message.id == replaceTempId);

      if (tempIndex >= 0) {
        updated = [..._messages];
        updated[tempIndex] = incoming;
      } else {
        updated = _insertOrAppendIncoming(incoming);
      }
    } else {
      updated = _insertOrAppendIncoming(incoming);
    }

    _messages = updated;
    notifyListeners();
  }

  List<ChatMessage> _insertOrAppendIncoming(ChatMessage incoming) {
    final pendingIndex = _messages.indexWhere(
      (message) =>
          message.isLocal &&
          message.profileId == incoming.profileId &&
          message.body == incoming.body,
    );

    if (pendingIndex >= 0) {
      final updated = [..._messages];
      updated[pendingIndex] = incoming;
      return updated;
    }

    return [..._messages, incoming];
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _realtime.dispose();
    super.dispose();
  }
}

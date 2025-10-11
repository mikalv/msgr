import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:messngr/features/chat/models/chat_message.dart';
import 'package:messngr/features/chat/models/chat_thread.dart';
import 'package:messngr/services/api/chat_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatViewModel extends ChangeNotifier {
  ChatViewModel({ChatApi? api}) : _api = api ?? ChatApi();

  final ChatApi _api;
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

  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  List<ChatMessage> get messages => _messages;
  ChatThread? get thread => _thread;
  AccountIdentity? get identity => _identity;

  Future<void> bootstrap() async {
    if (_isLoading) return;
    _setLoading(true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await _ensureIdentities(prefs);
      await _ensureConversation();
      await fetchMessages();
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
    final localMessage = ChatMessage(
      id: tempId,
      body: trimmed,
      profileId: _identity!.profileId,
      profileName: 'Deg',
      profileMode: 'private',
      status: 'sending',
      sentAt: DateTime.now(),
      insertedAt: DateTime.now(),
      isLocal: true,
    );

    _messages = [..._messages, localMessage];
    _error = null;
    _isSending = true;
    notifyListeners();

    try {
      final persisted = await _api.sendMessage(
        current: _identity!,
        conversationId: _thread!.id,
        body: trimmed,
      );

      _messages = [
        for (final message in _messages)
          if (message.id == tempId) persisted else message,
      ];
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
}

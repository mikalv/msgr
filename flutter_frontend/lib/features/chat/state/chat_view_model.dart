import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:messngr/features/chat/media/chat_media_uploader.dart';
import 'package:messngr/features/chat/models/chat_message.dart';
import 'package:messngr/features/chat/models/chat_thread.dart';
import 'package:messngr/features/chat/models/composer_submission.dart';
import 'package:messngr/services/api/chat_api.dart';
import 'package:messngr/services/api/chat_socket.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatViewModel extends ChangeNotifier {
  ChatViewModel({ChatApi? api, ChatRealtime? realtime, ChatMediaUploader? mediaUploader})
      : _api = api ?? ChatApi(),
        _realtime = realtime ?? ChatSocket(),
        _mediaUploader = mediaUploader ?? ChatMediaUploader();

  final ChatApi _api;
  final ChatRealtime _realtime;
  final ChatMediaUploader _mediaUploader;
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

  Future<void> createGroupConversation(String topic, List<String> participantIds) async {
    if (_identity == null) return;

    _setLoading(true);
    _setError(null);

    try {
      _thread = await _api.createGroupConversation(
        current: _identity!,
        topic: topic,
        participantIds: participantIds,
      );

      await fetchMessages();
    } on ApiException catch (error) {
      debugPrint('createGroupConversation failed: $error');
      _setError('Kunne ikke opprette gruppe (${error.statusCode}).');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createChannelConversation(String topic, List<String> participantIds) async {
    if (_identity == null) return;

    _setLoading(true);
    _setError(null);

    try {
      _thread = await _api.createChannelConversation(
        current: _identity!,
        topic: topic,
        participantIds: participantIds,
      );

      await fetchMessages();
    } on ApiException catch (error) {
      debugPrint('createChannelConversation failed: $error');
      _setError('Kunne ikke opprette kanal (${error.statusCode}).');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendMessage(ComposerSubmission submission) async {
    if (_identity == null || _thread == null) {
      return;
    }

    final text = submission.text.trim();
    final attachments = submission.attachments;

    if (text.isEmpty && attachments.isEmpty) {
      return;
    }

    _setError(null);
    _isSending = true;
    notifyListeners();

    try {
      if (attachments.isEmpty) {
        if (text.isNotEmpty) {
          await _sendTextOnly(text);
        }
      } else {
        final caption = text.isNotEmpty ? text : null;
        var isFirst = true;

        for (final attachment in attachments) {
          final message = await _mediaUploader.uploadAndSend(
            current: _identity!,
            conversationId: _thread!.id,
            attachment: attachment,
            caption: isFirst ? caption : null,
          );
          isFirst = false;
          _mergeMessage(message);
        }
      }
    } on ApiException catch (error) {
      debugPrint('sendMessage failed: $error');
      _setError('Kunne ikke sende melding (${error.statusCode}).');
    } on ChatMediaUploadException catch (error) {
      debugPrint('Media upload failed: $error');
      final status = error.statusCode != null ? '${error.statusCode}' : 'ukjent';
      _setError('Kunne ikke laste opp vedlegg ($status).');
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> _sendTextOnly(String text) async {
    final tempId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();
    final localMessage = ChatMessage.text(
      id: tempId,
      body: text,
      profileId: _identity!.profileId,
      profileName: 'Deg',
      profileMode: 'private',
      status: 'sending',
      sentAt: now,
      insertedAt: now,
      isLocal: true,
    );

    _messages = [..._messages, localMessage];
    notifyListeners();

    try {
      final persisted = await _sendOverPreferredChannel(text);
      _mergeMessage(persisted, replaceTempId: tempId);
    } on ChatSocketException catch (error, stack) {
      debugPrint('Realtime send failed: $error\n$stack');

      try {
        final persisted = await _api.sendStructuredMessage(
          current: _identity!,
          conversationId: _thread!.id,
          body: text,
        );
        _mergeMessage(persisted, replaceTempId: tempId);
      } on ApiException catch (fallbackError) {
        debugPrint('Fallback send failed: $fallbackError');
        _messages =
            _messages.where((message) => message.id != tempId).toList();
        _setError('Kunne ikke sende melding (${fallbackError.statusCode}).');
        rethrow;
      }
    } on ApiException catch (error) {
      debugPrint('sendMessage failed: $error');
      _messages = _messages.where((message) => message.id != tempId).toList();
      _setError('Kunne ikke sende melding (${error.statusCode}).');
      rethrow;
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

  void _setError(String? message) {
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

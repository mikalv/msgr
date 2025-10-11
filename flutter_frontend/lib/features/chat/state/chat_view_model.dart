import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:messngr/features/chat/models/chat_message.dart';
import 'package:messngr/features/chat/models/chat_thread.dart';
import 'package:messngr/features/chat/state/chat_cache_repository.dart';
import 'package:messngr/features/chat/widgets/chat_composer.dart';
import 'package:messngr/services/api/chat_api.dart';
import 'package:messngr/services/api/chat_socket.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatViewModel extends ChangeNotifier {
  ChatViewModel({
    ChatApi? api,
    ChatRealtime? realtime,
    ChatCacheStore? cache,
    Connectivity? connectivity,
    ChatComposerController? composer,
  })  : _api = api ?? ChatApi(),
        _realtime = realtime ?? ChatSocket(),
        _cache = cache ?? HiveChatCacheStore(),
        _connectivity = connectivity ?? Connectivity(),
        composerController = composer ?? ChatComposerController() {
    composerController.addListener(_handleComposerChanged);
  }

  final ChatApi _api;
  final ChatRealtime _realtime;
  final ChatCacheStore _cache;
  final Connectivity _connectivity;
  final ChatComposerController composerController;
  final _random = Random();

  static const _accountIdKey = 'chat.account.id';
  static const _profileIdKey = 'chat.profile.id';
  static const _peerProfileIdKey = 'chat.peer.profile.id';
  static const _lastThreadIdKey = 'chat.last.thread.id';

  bool _isLoading = false;
  bool _isSending = false;
  bool _isOffline = false;
  String? _error;
  List<ChatMessage> _messages = const [];
  ChatThread? _thread;
  List<ChatThread> _channels = const [];
  AccountIdentity? _identity;
  String? _peerProfileId;
  String? _selectedThreadId;
  final Map<String, Map<String, int>> _messageReactions = {};
  StreamSubscription<ChatMessage>? _realtimeSubscription;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _realtimeConnected = false;

  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get isOffline => _isOffline;
  String? get error => _error;
  List<ChatMessage> get messages => _messages;
  ChatThread? get thread => _thread;
  List<ChatThread> get channels => _channels;
  AccountIdentity? get identity => _identity;
  String? get selectedThreadId => _selectedThreadId;
  Map<String, int> reactionsFor(String messageId) =>
      _messageReactions[messageId] ?? const {};

  Future<void> bootstrap() async {
    if (_isLoading) return;
    _setLoading(true);
    _setError(null);

    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedThreadId = prefs.getString(_lastThreadIdKey);

      await _cache.initialise();
      await _observeConnectivity();
      await _hydrateFromCache();

      await _ensureIdentities(prefs);
      await _ensureConversation();
      await _fetchChannels();
      await fetchMessages();
      await _connectRealtime();
    } catch (error, stack) {
      debugPrint('Failed to bootstrap chat: $error\n$stack');
      if (_messages.isEmpty) {
        _setError('Klarte ikke å laste chatten.');
      }
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
      await _cache.saveMessages(_thread!.id, messages);
      _updateOffline(false);
      notifyListeners();
    } on ApiException catch (error) {
      debugPrint('fetchMessages failed: $error');
      final cached = await _cache.readMessages(_thread!.id);
      if (cached.isNotEmpty) {
        _messages = cached;
        _updateOffline(true);
        notifyListeners();
      } else {
        _setError('Kunne ikke hente meldinger (${error.statusCode}).');
      }
    }
  }

  Future<void> submitComposer(ChatComposerResult result) async {
    if (_identity == null || _thread == null) {
      if (result.command != null) {
        _handleSlashCommand(result.command!);
      }
      return;
    }

    if (result.command != null && result.text.isEmpty &&
        result.attachments.isEmpty && result.voiceNote == null) {
      _handleSlashCommand(result.command!);
      return;
    }

    final body = _composeBodyFromResult(result);
    if (body.trim().isEmpty && result.attachments.isEmpty && result.voiceNote == null) {
      return;
    }

    final tempId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();
    var localMessage = ChatMessage.text(
      id: tempId,
      body: body,
      profileId: _identity!.profileId,
      profileName: 'Deg',
      profileMode: 'private',
      status: _isOffline ? 'queued' : 'sending',
      sentAt: now,
      insertedAt: now,
      isLocal: true,
    );

    _messages = [..._messages, localMessage];
    _error = null;
    _isSending = true;
    notifyListeners();
    await _cache.saveMessages(_thread!.id, _messages);

    if (_isOffline) {
      _setError('Ingen nettverkstilkobling – meldingen ble lagret.');
      _isSending = false;
      notifyListeners();
      return;
    }

    try {
      final persisted = await _sendOverPreferredChannel(body);
      _mergeMessage(persisted, replaceTempId: tempId);
      await _cache.saveMessages(_thread!.id, _messages);
    } on ChatSocketException catch (error, stack) {
      debugPrint('Realtime send failed: $error\n$stack');
      try {
        final persisted = await _api.sendMessage(
          current: _identity!,
          conversationId: _thread!.id,
          body: body,
        );
        _mergeMessage(persisted, replaceTempId: tempId);
        await _cache.saveMessages(_thread!.id, _messages);
      } on ApiException catch (fallbackError) {
        debugPrint('Fallback send failed: $fallbackError');
        _messages =
            _messages.where((message) => message.id != tempId).toList();
        await _cache.saveMessages(_thread!.id, _messages);
        _setError('Kunne ikke sende melding (${fallbackError.statusCode}).');
      }
    } on ApiException catch (error) {
      debugPrint('sendMessage failed: $error');
      _messages = _messages.where((message) => message.id != tempId).toList();
      await _cache.saveMessages(_thread!.id, _messages);
      _setError('Kunne ikke sende melding (${error.statusCode}).');
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> selectThread(ChatThread thread) async {
    _thread = thread;
    _selectedThreadId = thread.id;
    await _cache.saveThreads([thread]);
    await _saveLastThreadId(thread.id);

    final cachedMessages = await _cache.readMessages(thread.id);
    if (cachedMessages.isNotEmpty) {
      _messages = cachedMessages;
      notifyListeners();
    }

    await fetchMessages();
    await _connectRealtime();
  }

  void addReaction(String messageId, String reaction) {
    final map = _messageReactions.putIfAbsent(messageId, () => {});
    map[reaction] = (map[reaction] ?? 0) + 1;
    notifyListeners();
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
      _selectedThreadId = _thread!.id;
      await _fetchChannels();
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
      _selectedThreadId = _thread!.id;
      await _fetchChannels();
      await fetchMessages();
    } on ApiException catch (error) {
      debugPrint('createChannelConversation failed: $error');
      _setError('Kunne ikke opprette kanal (${error.statusCode}).');
    } finally {
      _setLoading(false);
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
    if (_identity == null) return;

    if (_selectedThreadId != null) {
      final cached = _channels.firstWhere(
        (thread) => thread.id == _selectedThreadId,
        orElse: () => _thread ?? const ChatThread(
          id: '',
          participantNames: const [],
          kind: ChatThreadKind.direct,
        ),
      );
      if (cached.id.isNotEmpty) {
        _thread = cached;
        return;
      }
    }

    if (_peerProfileId == null) {
      final prefs = await SharedPreferences.getInstance();
      _peerProfileId = prefs.getString(_peerProfileIdKey);
    }

    if (_peerProfileId == null) return;

    _thread = await _api.ensureDirectConversation(
      current: _identity!,
      targetProfileId: _peerProfileId!,
    );
    _selectedThreadId = _thread!.id;
    await _cache.saveThreads([_thread!]);
    await _saveLastThreadId(_thread!.id);
  }

  Future<void> _fetchChannels() async {
    if (_identity == null) return;

    try {
      final threads = await _api.listConversations(current: _identity!);
      if (threads.isNotEmpty) {
        _channels = threads;
        await _cache.saveThreads(threads);
        if (_selectedThreadId != null) {
          final selected = threads.firstWhere(
            (thread) => thread.id == _selectedThreadId,
            orElse: () => threads.first,
          );
          _thread = selected;
        } else {
          _thread = threads.first;
          _selectedThreadId = _thread!.id;
        }
        await _saveLastThreadId(_selectedThreadId!);
      }
      notifyListeners();
    } on ApiException catch (error) {
      debugPrint('listConversations failed: $error');
      if (_channels.isEmpty) {
        _channels = await _cache.readThreads();
        if (_channels.isNotEmpty && _thread == null) {
          _thread = _channels.first;
          _selectedThreadId = _thread!.id;
        }
        notifyListeners();
      }
    }
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
        (message) {
          _mergeMessage(message);
          _cache.saveMessages(_thread!.id, _messages);
        },
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

  void _updateOffline(bool offline) {
    if (_isOffline == offline) return;
    _isOffline = offline;
    notifyListeners();
  }

  Future<void> _observeConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _updateOffline(result == ConnectivityResult.none);
    await _connectivitySubscription?.cancel();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((result) {
      final offline = result == ConnectivityResult.none;
      final wasOffline = _isOffline;
      _updateOffline(offline);
      if (wasOffline && !offline) {
        fetchMessages();
      }
    });
  }

  Future<void> _hydrateFromCache() async {
    final threads = await _cache.readThreads();
    if (threads.isNotEmpty) {
      _channels = threads;
    }

    String? threadId = _selectedThreadId;
    if (threadId == null && threads.isNotEmpty) {
      threadId = threads.first.id;
    }

    if (threadId != null) {
      final cachedMessages = await _cache.readMessages(threadId);
      if (cachedMessages.isNotEmpty) {
        _messages = cachedMessages;
        _selectedThreadId = threadId;
      }
      final draft = await _cache.readDraft(threadId);
      if (draft != null && draft.isNotEmpty) {
        composerController.setText(draft);
      }
    }

    notifyListeners();
  }

  void _handleComposerChanged() {
    final threadId = _thread?.id ?? _selectedThreadId;
    if (threadId != null) {
      _cache.saveDraft(threadId, composerController.value.text);
    }
  }

  void _handleSlashCommand(SlashCommand command) {
    final now = DateTime.now();
    final systemMessage = ChatMessage.text(
      id: 'command-${now.microsecondsSinceEpoch}',
      body: 'Kommando ${command.name} registrert – ${command.description}',
      profileId: _identity?.profileId ?? 'system',
      profileName: 'Automatikk',
      profileMode: 'system',
      status: 'delivered',
      sentAt: now,
      insertedAt: now,
      isLocal: true,
    );
    _messages = [..._messages, systemMessage];
    notifyListeners();
  }

  String _composeBodyFromResult(ChatComposerResult result) {
    final buffer = StringBuffer(result.text.trim());
    if (result.attachments.isNotEmpty) {
      final attachmentSummary = result.attachments
          .map((attachment) => attachment.name)
          .join(', ');
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('Vedlegg: $attachmentSummary');
    }
    if (result.voiceNote != null) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write('Lydklipp ${result.voiceNote!.formattedDuration} vedlagt.');
    }
    return buffer.toString();
  }

  Future<void> _saveLastThreadId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastThreadIdKey, id);
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
    composerController.removeListener(_handleComposerChanged);
    _realtimeSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _realtime.dispose();
    super.dispose();
  }
}

import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:messngr/features/chat/models/chat_message.dart';
import 'package:messngr/features/chat/models/chat_thread.dart';
import 'package:messngr/features/chat/models/reaction_aggregate.dart';
import 'package:messngr/features/chat/state/chat_cache_repository.dart';
import 'package:messngr/features/chat/state/message_editing_notifier.dart';
import 'package:messngr/features/chat/state/pinned_messages_notifier.dart';
import 'package:messngr/features/chat/state/reaction_aggregator_notifier.dart';
import 'package:messngr/features/chat/state/thread_view_notifier.dart';
import 'package:messngr/features/chat/state/typing_participants_notifier.dart';
import 'package:messngr/features/chat/widgets/chat_composer.dart';
import 'package:messngr/features/chat/upload/chat_media_uploader.dart';
import 'package:messngr/services/api/chat_api.dart';
import 'package:messngr/services/api/chat_socket.dart';
import 'package:messngr/services/api/chat_realtime_event.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatViewModel extends ChangeNotifier {
  ChatViewModel({
    ChatApi? api,
    ChatRealtime? realtime,
    ChatCacheStore? cache,
    Connectivity? connectivity,
    ChatComposerController? composer,
    TypingParticipantsNotifier? typing,
    ReactionAggregatorNotifier? reactions,
    PinnedMessagesNotifier? pinned,
    ThreadViewNotifier? threadView,
    MessageEditingNotifier? editing,
    ChatMediaUploader? mediaUploader,
  })  : _api = api ?? ChatApi(),
        _realtime = realtime ?? ChatSocket(),
        _cache = cache ?? HiveChatCacheStore(),
        _connectivity = connectivity ?? Connectivity(),
        composerController = composer ?? ChatComposerController(),
        typingNotifier = typing ?? TypingParticipantsNotifier(),
        reactionNotifier = reactions ?? ReactionAggregatorNotifier(),
        pinnedNotifier = pinned ?? PinnedMessagesNotifier(),
        threadViewNotifier = threadView ?? ThreadViewNotifier(),
        messageEditingNotifier = editing ?? MessageEditingNotifier(),
        _mediaUploader = mediaUploader {
    composerController.addListener(_handleComposerChanged);
  }

  final ChatApi _api;
  final ChatRealtime _realtime;
  final ChatCacheStore _cache;
  final Connectivity _connectivity;
  final ChatComposerController composerController;
  final TypingParticipantsNotifier typingNotifier;
  final ReactionAggregatorNotifier reactionNotifier;
  final PinnedMessagesNotifier pinnedNotifier;
  final ThreadViewNotifier threadViewNotifier;
  final MessageEditingNotifier messageEditingNotifier;
  final _random = Random();
  ChatMediaUploader? _mediaUploader;

  static const _typingIdleDuration = Duration(seconds: 5);

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
  StreamSubscription<ChatRealtimeEvent>? _realtimeSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _realtimeConnected = false;
  Timer? _typingTimer;
  bool _typingActive = false;
  final Set<String> _acknowledgedReads = <String>{};

  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get isOffline => _isOffline;
  String? get error => _error;
  List<ChatMessage> get messages => _messages;
  ChatThread? get thread => _thread;
  List<ChatThread> get channels => _channels;
  AccountIdentity? get identity => _identity;
  String? get selectedThreadId => _selectedThreadId;
  List<ReactionAggregate> reactionsFor(String messageId) =>
      reactionNotifier.aggregatesFor(messageId);

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
      for (final message in messages) {
        if (message.isDeleted) {
          messageEditingNotifier.markDeleted(message.id);
        } else {
          messageEditingNotifier.restore(message.id);
        }
      }
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

  void recordReaction(String messageId, String emoji) {
    final existing = reactionsFor(messageId).toList();
    final index = existing.indexWhere((aggregate) => aggregate.emoji == emoji);
    if (index >= 0) {
      final aggregate = existing[index];
      existing[index] = aggregate.copyWith(count: aggregate.count + 1);
    } else {
      existing.add(
        ReactionAggregate(
          emoji: emoji,
          count: 1,
          profileIds: [identity?.profileId ?? 'self'],
        ),
      );
    }
    reactionNotifier.apply(messageId, existing);
    notifyListeners();

    _sendReactionCommand(messageId, emoji);
  }

  void applyReactionAggregates(
      String messageId, List<ReactionAggregate> aggregates) {
    reactionNotifier.apply(messageId, aggregates);
    notifyListeners();
  }

  void pinMessage(PinnedMessageInfo info) {
    pinnedNotifier.pin(info);
    notifyListeners();
  }

  void unpinMessage(String messageId) {
    pinnedNotifier.unpin(messageId);
    notifyListeners();
  }

  Future<void> requestPinMessage(String messageId,
      {Map<String, dynamic>? metadata}) async {
    if (!_realtimeConnected || !_realtime.isConnected) {
      return;
    }

    try {
      await _realtime.pinMessage(messageId, metadata: metadata);
    } catch (error, stack) {
      debugPrint('Failed to pin message: $error\n$stack');
    }
  }

  Future<void> requestUnpinMessage(String messageId) async {
    if (!_realtimeConnected || !_realtime.isConnected) {
      return;
    }

    try {
      await _realtime.unpinMessage(messageId);
    } catch (error, stack) {
      debugPrint('Failed to unpin message: $error\n$stack');
    }
  }

  Future<void> submitComposer(ChatComposerResult result) async {
    if (_identity == null || _thread == null) {
      if (result.command != null) {
        _handleSlashCommand(result.command!);
      }
      return;
    }

    final attachments = result.attachments;
    final voiceNote = result.voiceNote;
    var remainingText = result.text.trim();

    if (result.command != null &&
        remainingText.isEmpty &&
        attachments.isEmpty &&
        voiceNote == null) {
      _handleSlashCommand(result.command!);
      return;
    }

    if (attachments.isEmpty && voiceNote == null) {
      final trimmed = remainingText.trim();
      if (trimmed.isEmpty) {
        return;
      }
      await _sendTextOnly(trimmed);
      composerController.clear();
      return;
    }

    if (_isOffline) {
      _setError('Ingen nettverkstilkobling – kan ikke laste opp media.');
      return;
    }

    final uploader = _ensureMediaUploader();

    _setError(null);
    _isSending = true;
    notifyListeners();

    try {
      if (voiceNote != null) {
        final caption = remainingText.isNotEmpty ? remainingText : null;
        final payload = await uploader.uploadVoiceNote(
          conversationId: _thread!.id,
          note: voiceNote,
          caption: caption,
        );
        if (caption != null) {
          remainingText = '';
        }
        final persisted = await _api.sendStructuredMessage(
          current: _identity!,
          conversationId: _thread!.id,
          message: payload.message,
        );
        _mergeMessage(persisted);
      }

      for (var i = 0; i < attachments.length; i++) {
        final attachment = attachments[i];
        final caption =
            (i == 0 && remainingText.isNotEmpty) ? remainingText : null;
        if (caption != null) {
          remainingText = '';
        }
        final payload = await uploader.uploadAttachment(
          conversationId: _thread!.id,
          attachment: attachment,
          caption: caption,
        );
        final persisted = await _api.sendStructuredMessage(
          current: _identity!,
          conversationId: _thread!.id,
          message: payload.message,
        );
        _mergeMessage(persisted);
      }

      if (remainingText.trim().isNotEmpty) {
        await _sendTextOnly(remainingText);
      }

      composerController.clear();
      await _cache.saveMessages(_thread!.id, _messages);
    } on ApiException catch (error) {
      debugPrint('media send failed: $error');
      _setError('Kunne ikke sende media (${error.statusCode}).');
    } catch (error, stack) {
      debugPrint('media upload failed: $error\n$stack');
      _setError('Kunne ikke sende media.');
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  ChatMediaUploader _ensureMediaUploader() {
    if (_identity == null) {
      throw StateError('Kan ikke laste opp media uten innlogget identitet.');
    }
    return _mediaUploader ??=
        ChatMediaUploader(api: _api, identity: _identity!);
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
      status: _isOffline ? 'queued' : 'sending',
      sentAt: now,
      insertedAt: now,
      isLocal: true,
    );

    _messages = [..._messages, localMessage];
    notifyListeners();
    await _cache.saveMessages(_thread!.id, _messages);

    if (_isOffline) {
      _setError('Ingen nettverkstilkobling – meldingen ble lagret.');
      return;
    }

    try {
      final persisted = await _sendOverPreferredChannel(text);
      _mergeMessage(persisted, replaceTempId: tempId);
      await _cache.saveMessages(_thread!.id, _messages);
    } on ChatSocketException catch (error, stack) {
      debugPrint('Realtime send failed: $error\n$stack');
      try {
        final persisted = await _api.sendStructuredMessage(
          current: _identity!,
          conversationId: _thread!.id,
          body: text,
        );
        _mergeMessage(persisted, replaceTempId: tempId);
        await _cache.saveMessages(_thread!.id, _messages);
      } on ApiException catch (fallbackError) {
        debugPrint('Fallback send failed: $fallbackError');
        _messages = _messages.where((message) => message.id != tempId).toList();
        await _cache.saveMessages(_thread!.id, _messages);
        _setError('Kunne ikke sende melding (${fallbackError.statusCode}).');
        rethrow;
      }
    } on ApiException catch (error) {
      debugPrint('sendMessage failed: $error');
      _messages = _messages.where((message) => message.id != tempId).toList();
      await _cache.saveMessages(_thread!.id, _messages);
      _setError('Kunne ikke sende melding (${error.statusCode}).');
      rethrow;
    } finally {
      _isSending = false;
      notifyListeners();
      _stopTypingActivity();
    }
  }

  Future<void> selectThread(ChatThread thread) async {
    reactionNotifier.clear();
    pinnedNotifier.clear();
    typingNotifier.clear();
    threadViewNotifier.closeThread();
    threadViewNotifier.setPinnedView(false);
    _acknowledgedReads.clear();
    _stopTypingActivity();
    notifyListeners();

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

  Future<void> createGroupConversation(
      String topic, List<String> participantIds) async {
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

  Future<void> createChannelConversation(
      String topic, List<String> participantIds) async {
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
      _mediaUploader = ChatMediaUploader(api: _api, identity: _identity!);
      return;
    }

    final mainIdentity = await _api.createAccount('Demo ${_suffix()}',
        email: _debugEmail('demo'));
    final buddyIdentity = await _api.createAccount('Companion ${_suffix()}',
        email: _debugEmail('buddy'));

    await prefs.setString(_accountIdKey, mainIdentity.accountId);
    await prefs.setString(_profileIdKey, mainIdentity.profileId);
    await prefs.setString(_peerProfileIdKey, buddyIdentity.profileId);

    _identity = mainIdentity;
    _peerProfileId = buddyIdentity.profileId;
    _mediaUploader = ChatMediaUploader(api: _api, identity: _identity!);
  }

  Future<void> _ensureConversation() async {
    if (_identity == null) return;

    if (_selectedThreadId != null) {
      final cached = _channels.firstWhere(
        (thread) => thread.id == _selectedThreadId,
        orElse: () =>
            _thread ??
            const ChatThread(
              id: '',
              participantNames: const [],
              kind: ChatThreadKind.direct,
            ),
      );
      if (cached.id.isNotEmpty) {
        _thread = cached;
        _acknowledgedReads.clear();
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
    _acknowledgedReads.clear();
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
      _realtimeSubscription = _realtime.events.listen(
        _handleRealtimeEvent,
        onError: (error) {
          debugPrint('Realtime stream error: $error');
          _realtimeConnected = false;
          _stopTypingActivity();
        },
      );
      _markExistingMessagesRead();
    } on ChatSocketException catch (error, stack) {
      debugPrint('Failed to connect realtime: $error\n$stack');
      _realtimeConnected = false;
      _stopTypingActivity();
    } catch (error, stack) {
      debugPrint('Unexpected realtime error: $error\n$stack');
      _realtimeConnected = false;
      _stopTypingActivity();
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
    final results = await _connectivity.checkConnectivity();
    _updateOffline(results.contains(ConnectivityResult.none));
    await _connectivitySubscription?.cancel();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      final offline = results.contains(ConnectivityResult.none);
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
    _updateTypingState(composerController.value.text.trim().isNotEmpty);
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
    return result.text.trim();
  }

  void _sendReactionCommand(String messageId, String emoji) {
    if (!_realtimeConnected || !_realtime.isConnected) {
      return;
    }

    () async {
      try {
        await _realtime.addReaction(messageId, emoji);
      } catch (error, stack) {
        debugPrint('Failed to send reaction: $error\n$stack');
      }
    }();
  }

  void _handleRealtimeEvent(ChatRealtimeEvent event) {
    if (_thread == null) return;

    if (event is ChatMessageEvent) {
      _mergeMessage(event.message);
      _persistMessages();
      _markMessageRead(event.message);
      return;
    }

    if (event is ChatMessageDeletedEvent) {
      _applyMessageDeleted(event);
      return;
    }

    if (event is ChatReactionEvent) {
      reactionNotifier.apply(event.messageId, event.aggregates);
      notifyListeners();
      return;
    }

    if (event is ChatPinnedEvent) {
      if (event.isPinned) {
        pinMessage(
          PinnedMessageInfo(
            messageId: event.messageId,
            pinnedById: event.pinnedById,
            pinnedAt: event.pinnedAt.toLocal(),
            metadata: event.metadata,
          ),
        );
      } else {
        unpinMessage(event.messageId);
      }
      return;
    }

    if (event is ChatTypingEvent) {
      if (event.isTyping) {
        typingNotifier.setTyping(
          profileId: event.profileId,
          profileName: event.profileName,
          threadId: event.threadId,
          expiresAt: event.expiresAt?.toLocal(),
        );
      } else {
        typingNotifier.stopTyping(
          profileId: event.profileId,
          threadId: event.threadId,
        );
      }
      notifyListeners();
      return;
    }

    if (event is ChatReadEvent) {
      _applyReadEvent(event);
    }
  }

  void _applyMessageDeleted(ChatMessageDeletedEvent event) {
    final index =
        _messages.indexWhere((message) => message.id == event.messageId);
    if (index < 0) {
      return;
    }

    final deletedAt = event.deletedAt ?? DateTime.now().toUtc();
    final message = _messages[index].copyWith(
      body: '',
      status: 'deleted',
      deletedAt: deletedAt,
    );

    final updated = [..._messages];
    updated[index] = message;
    _messages = updated;
    messageEditingNotifier.markDeleted(message.id);
    notifyListeners();
    _persistMessages();
  }

  void _applyReadEvent(ChatReadEvent event) {
    final identity = _identity;
    if (identity == null || event.profileId == identity.profileId) {
      return;
    }

    final index =
        _messages.indexWhere((message) => message.id == event.messageId);
    if (index < 0) {
      return;
    }

    final message = _messages[index];
    if (message.profileId != identity.profileId) {
      return;
    }

    final updatedMessage = message.copyWith(status: 'read');
    final updated = [..._messages];
    updated[index] = updatedMessage;
    _messages = updated;
    notifyListeners();
    _persistMessages();
  }

  void _markMessageRead(ChatMessage message) {
    final identity = _identity;
    if (identity == null) return;
    if (message.profileId == identity.profileId) return;
    if (!_realtimeConnected || !_realtime.isConnected) return;
    if (!_acknowledgedReads.add(message.id)) return;

    () async {
      try {
        await _realtime.markRead(message.id);
      } catch (error, stack) {
        debugPrint('Failed to mark message read: $error\n$stack');
      }
    }();
  }

  void _markExistingMessagesRead() {
    final identity = _identity;
    if (identity == null) return;

    for (final message in _messages) {
      if (message.profileId != identity.profileId) {
        _markMessageRead(message);
      }
    }
  }

  void _persistMessages() {
    final threadId = _thread?.id;
    if (threadId == null) {
      return;
    }

    () async {
      try {
        await _cache.saveMessages(threadId, _messages);
      } catch (error, stack) {
        debugPrint('Failed to persist chat cache: $error\n$stack');
      }
    }();
  }

  void _updateTypingState(bool hasContent) {
    if (!_realtimeConnected || !_realtime.isConnected) {
      return;
    }

    if (hasContent) {
      if (!_typingActive) {
        _typingActive = true;
        _sendTypingCommand(start: true);
      }

      _typingTimer?.cancel();
      _typingTimer = Timer(_typingIdleDuration, () {
        _typingActive = false;
        _sendTypingCommand(start: false);
      });
    } else {
      if (_typingActive) {
        _typingActive = false;
        _sendTypingCommand(start: false);
      }
      _typingTimer?.cancel();
      _typingTimer = null;
    }
  }

  void _sendTypingCommand({required bool start}) {
    if (!_realtimeConnected || !_realtime.isConnected) {
      return;
    }

    final threadId = threadViewNotifier.state.threadId;

    () async {
      try {
        if (start) {
          await _realtime.startTyping(threadId: threadId);
        } else {
          await _realtime.stopTyping(threadId: threadId);
        }
      } catch (error, stack) {
        debugPrint('Failed to send typing state: $error\n$stack');
      }
    }();
  }

  void _stopTypingActivity() {
    _typingTimer?.cancel();
    _typingTimer = null;
    if (!_typingActive) {
      return;
    }
    _typingActive = false;
    _sendTypingCommand(start: false);
  }

  Future<void> _saveLastThreadId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastThreadIdKey, id);
  }

  String _suffix() => (_random.nextInt(9000) + 1000).toString();

  String _debugEmail(String label) =>
      '$label-${DateTime.now().millisecondsSinceEpoch}@msgr.dev';

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
    if (incoming.isDeleted) {
      messageEditingNotifier.markDeleted(incoming.id);
    } else {
      messageEditingNotifier.restore(incoming.id);
    }
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
    _stopTypingActivity();
    _realtime.dispose();
    typingNotifier.clear();
    reactionNotifier.clear();
    pinnedNotifier.clear();
    messageEditingNotifier.clear();
    super.dispose();
  }
}

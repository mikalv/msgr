import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:messngr/features/chat/models/chat_message.dart';
import 'package:messngr/features/chat/models/chat_thread.dart';
import 'package:messngr/features/chat/models/reaction_aggregate.dart';
import 'package:messngr/features/chat/state/chat_cache_repository.dart';
import 'package:messngr/features/chat/state/composer_autosave_manager.dart';
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
import 'package:messngr/services/api/contact_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatViewModel extends ChangeNotifier {
  ChatViewModel({
    required AccountIdentity identity,
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
    ContactApi? contacts,
  })  : _identity = identity,
        _api = api ?? ChatApi(),
        _realtime = realtime ?? ChatSocket(),
        _cache = cache ?? HiveChatCacheStore(),
        _connectivity = connectivity ?? Connectivity(),
        _contactApi = contacts ?? ContactApi(),
        composerController = composer ?? ChatComposerController(),
        typingNotifier = typing ?? TypingParticipantsNotifier(),
        reactionNotifier = reactions ?? ReactionAggregatorNotifier(),
        pinnedNotifier = pinned ?? PinnedMessagesNotifier(),
        threadViewNotifier = threadView ?? ThreadViewNotifier(),
        messageEditingNotifier = editing ?? MessageEditingNotifier() {
    _mediaUploader =
        mediaUploader ?? ChatMediaUploader(api: _api, identity: _identity);
    composerController.addListener(_handleComposerChanged);
    _autosaveManager = ComposerDraftAutosaveManager(
      cache: _cache,
      controller: composerController,
    );
  }

  final ChatApi _api;
  final ChatRealtime _realtime;
  final ChatCacheStore _cache;
  final Connectivity _connectivity;
  final ContactApi _contactApi;
  final ChatComposerController composerController;
  final TypingParticipantsNotifier typingNotifier;
  final ReactionAggregatorNotifier reactionNotifier;
  final PinnedMessagesNotifier pinnedNotifier;
  final ThreadViewNotifier threadViewNotifier;
  final MessageEditingNotifier messageEditingNotifier;
  late final ChatMediaUploader _mediaUploader;
  final AccountIdentity _identity;
  late final ComposerDraftAutosaveManager _autosaveManager;

  static const _typingIdleDuration = Duration(seconds: 5);

  static const _lastThreadIdKey = 'chat.last.thread.id';

  bool _isLoading = false;
  bool _isSending = false;
  bool _isOffline = false;
  String? _error;
  List<ChatMessage> _messages = const [];
  ChatThread? _thread;
  List<ChatThread> _channels = const [];
  String? _selectedThreadId;
  StreamSubscription<ChatRealtimeEvent>? _realtimeSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _realtimeConnected = false;
  Timer? _typingTimer;
  bool _typingActive = false;
  final Set<String> _acknowledgedReads = <String>{};
  bool _suppressComposerPersistence = false;

  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get isOffline => _isOffline;
  bool get isRealtimeConnected => _realtimeConnected;
  String? get error => _error;
  List<ChatMessage> get messages => _messages;
  ChatThread? get thread => _thread;
  List<ChatThread> get channels => _channels;
  AccountIdentity get identity => _identity;
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
    if (_thread == null) return;

    try {
      final messages = await _api.fetchMessages(
        current: _identity,
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
          profileIds: [_identity.profileId],
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
    if (_thread == null) {
      if (result.command != null) {
        _handleSlashCommand(result.command!);
      }
      return;
    }

    await _autosaveManager.flushNow();

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
      _error = null;
      composerController.setSendState(ComposerSendState.sending);
      _isSending = true;
      notifyListeners();
      final success = await _sendTextOnly(trimmed);
      _isSending = false;
      if (_isOffline) {
        composerController.setSendState(ComposerSendState.queuedOffline);
      } else {
        composerController.setSendState(
          success ? ComposerSendState.idle : ComposerSendState.failed,
          error: _error,
        );
      }
      notifyListeners();
      if (success) {
        composerController.clear();
      }
      return;
    }

    if (_isOffline) {
      const message = 'Ingen nettverkstilkobling – kan ikke laste opp media.';
      _setError(message);
      composerController.setSendState(
        ComposerSendState.failed,
        error: message,
      );
      return;
    }

    final uploader = _ensureMediaUploader();

    _setError(null);
    composerController.setSendState(ComposerSendState.sending);
    _isSending = true;
    notifyListeners();

    var shouldClearComposer = true;
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
          current: _identity,
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
          current: _identity,
          conversationId: _thread!.id,
          message: payload.message,
        );
        _mergeMessage(persisted);
      }

      if (remainingText.trim().isNotEmpty) {
        final sent = await _sendTextOnly(remainingText);
        if (!sent) {
          shouldClearComposer = false;
        }
      }

      await _cache.saveMessages(_thread!.id, _messages);
    } on ApiException catch (error) {
      debugPrint('media send failed: $error');
      final message = 'Kunne ikke sende media (${error.statusCode}).';
      _setError(message);
      composerController.setSendState(
        ComposerSendState.failed,
        error: message,
      );
      shouldClearComposer = false;
    } catch (error, stack) {
      debugPrint('media upload failed: $error\n$stack');
      const message = 'Kunne ikke sende media.';
      _setError(message);
      composerController.setSendState(
        ComposerSendState.failed,
        error: message,
      );
      shouldClearComposer = false;
    } finally {
      _isSending = false;
      composerController.setSendState(ComposerSendState.idle);
      notifyListeners();
      if (shouldClearComposer) {
        composerController.clear();
      }
    }
  }

  ChatMediaUploader _ensureMediaUploader() => _mediaUploader;

  Future<bool> _sendTextOnly(String text) async {
    final tempId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();
    final trimmed = text.trim();
    if (trimmed.isEmpty || _thread == null) {
      return false;
    }

    final localMessage = ChatMessage.text(
      id: tempId,
      body: trimmed,
      profileId: _identity.profileId,
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
      const message = 'Ingen nettverkstilkobling – meldingen ble lagret.';
      _setError(message);
      composerController.setSendState(
        ComposerSendState.queuedOffline,
        error: message,
      );
      _stopTypingActivity();
      return true;
    }

    try {
      final persisted = await _sendOverPreferredChannel(trimmed);
      _mergeMessage(persisted, replaceTempId: tempId);
      await _cache.saveMessages(_thread!.id, _messages);
      return true;
    } on ChatSocketException catch (error, stack) {
      debugPrint('Realtime send failed: $error\n$stack');
      try {
        final persisted = await _api.sendStructuredMessage(
          current: _identity,
          conversationId: _thread!.id,
          body: trimmed,
        );
        _mergeMessage(persisted, replaceTempId: tempId);
        await _cache.saveMessages(_thread!.id, _messages);
        return true;
      } on ApiException catch (fallbackError) {
        debugPrint('Fallback send failed: $fallbackError');
        _messages = _messages.where((message) => message.id != tempId).toList();
        await _cache.saveMessages(_thread!.id, _messages);
        final message = 'Kunne ikke sende melding (${fallbackError.statusCode}).';
        _setError(message);
        composerController.setSendState(
          ComposerSendState.failed,
          error: message,
        );
        return false;
      }
    } on ApiException catch (error) {
      debugPrint('sendMessage failed: $error');
      _messages = _messages.where((message) => message.id != tempId).toList();
      await _cache.saveMessages(_thread!.id, _messages);
      final message = 'Kunne ikke sende melding (${error.statusCode}).';
      _setError(message);
      composerController.setSendState(
        ComposerSendState.failed,
        error: message,
      );
      return false;
    } catch (error, stack) {
      debugPrint('sendMessage failed unexpectedly: $error\n$stack');
      _messages = _messages.where((message) => message.id != tempId).toList();
      await _cache.saveMessages(_thread!.id, _messages);
      const message = 'Kunne ikke sende melding.';
      _setError(message);
      composerController.setSendState(
        ComposerSendState.failed,
        error: message,
      );
      return false;
    } finally {
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

    await _autosaveManager.flushNow();

    _thread = thread;
    _selectedThreadId = thread.id;
    await _saveLastThreadId(thread.id);

    final cachedMessages = await _cache.readMessages(thread.id);
    if (cachedMessages.isNotEmpty) {
      _messages = cachedMessages;
      notifyListeners();
    }

    final draft = await _cache.readDraft(thread.id);
    _restoreComposerDraft(draft);

    await fetchMessages();
    await _connectRealtime();
  }

  Future<void> createGroupConversation(
      String topic, List<String> participantIds) async {
    _setLoading(true);
    _setError(null);

    try {
      final thread = await _api.createGroupConversation(
        current: _identity,
        topic: topic,
        participantIds: participantIds,
      );
      _selectedThreadId = thread.id;
      await _fetchChannels(preselectThreadId: thread.id);
      final resolved = _channels.firstWhere(
        (item) => item.id == thread.id,
        orElse: () => thread,
      );
      await selectThread(resolved);
    } on ApiException catch (error) {
      debugPrint('createGroupConversation failed: $error');
      _setError('Kunne ikke opprette gruppe (${error.statusCode}).');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createChannelConversation(
      String topic, List<String> participantIds) async {
    _setLoading(true);
    _setError(null);

    try {
      final thread = await _api.createChannelConversation(
        current: _identity,
        topic: topic,
        participantIds: participantIds,
      );
      _selectedThreadId = thread.id;
      await _fetchChannels(preselectThreadId: thread.id);
      final resolved = _channels.firstWhere(
        (item) => item.id == thread.id,
        orElse: () => thread,
      );
      await selectThread(resolved);
    } on ApiException catch (error) {
      debugPrint('createChannelConversation failed: $error');
      _setError('Kunne ikke opprette kanal (${error.statusCode}).');
    } finally {
      _setLoading(false);
    }
  }

  Future<KnownContactMatch?> lookupContactByEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return null;

    final matches = await _contactApi.lookupKnownContacts(
      current: _identity,
      targets: [ContactImportEntry(email: trimmed)],
    );

    return matches.isNotEmpty ? matches.first : null;
  }

  Future<void> startDirectConversation(String targetProfileId) async {
    final trimmed = targetProfileId.trim();
    if (trimmed.isEmpty) {
      _setError('Profil-ID kan ikke være tom.');
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      final thread = await _api.ensureDirectConversation(
        current: _identity,
        targetProfileId: trimmed,
      );

      await _fetchChannels(preselectThreadId: thread.id);
      final resolved = _channels.firstWhere(
        (item) => item.id == thread.id,
        orElse: () => thread,
      );
      await selectThread(resolved);
    } on ApiException catch (error) {
      debugPrint('ensureDirectConversation failed: $error');
      _setError('Kunne ikke starte samtale (${error.statusCode}).');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _fetchChannels({String? preselectThreadId}) async {
    try {
      final threads = await _api.listConversations(current: _identity);
      _channels = threads;
      await _cache.saveThreads(threads);
      if (threads.isNotEmpty) {
        final preferredId = preselectThreadId ?? _selectedThreadId;
        if (preferredId != null) {
          final selected = threads.firstWhere(
            (thread) => thread.id == preferredId,
            orElse: () => threads.first,
          );
          _thread = selected;
        } else {
          _thread = threads.first;
          _selectedThreadId = _thread!.id;
        }
        _selectedThreadId = _thread!.id;
        await _saveLastThreadId(_selectedThreadId!);
      } else {
        _thread = null;
        _selectedThreadId = null;
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
    if (_thread == null) return;

    try {
      await _realtimeSubscription?.cancel();
      final subscription = _realtime.events.listen(
        _handleRealtimeEvent,
        onError: (error) {
          debugPrint('Realtime stream error: $error');
          _realtimeConnected = false;
          _stopTypingActivity();
          notifyListeners();
        },
      );
      _realtimeSubscription = subscription;

      await _realtime.connect(
        identity: _identity,
        conversationId: _thread!.id,
      );

      if (_realtime.isConnected) {
        _realtimeConnected = true;
        _markExistingMessagesRead();
      }
    } on ChatSocketException catch (error, stack) {
      debugPrint('Failed to connect realtime: $error\n$stack');
      _realtimeConnected = false;
      _stopTypingActivity();
      await _realtimeSubscription?.cancel();
      _realtimeSubscription = null;
      notifyListeners();
    } catch (error, stack) {
      debugPrint('Unexpected realtime error: $error\n$stack');
      _realtimeConnected = false;
      _stopTypingActivity();
      await _realtimeSubscription?.cancel();
      _realtimeSubscription = null;
      notifyListeners();
    }
  }

  Future<ChatMessage> _sendOverPreferredChannel(String body) async {
    if (_realtimeConnected && _realtime.isConnected) {
      return _realtime.send(body);
    }

    return _api.sendMessage(
      current: _identity,
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

  void _restoreComposerDraft(ChatDraftSnapshot? snapshot) {
    _suppressComposerPersistence = true;
    try {
      if (snapshot == null || snapshot.isEmpty) {
        composerController.clear();
      } else {
        composerController.restoreSnapshot(snapshot);
      }
    } finally {
      _suppressComposerPersistence = false;
    }
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
      _restoreComposerDraft(draft);
    }

    notifyListeners();
  }

  void _handleComposerChanged() {
    if (_suppressComposerPersistence) {
      return;
    }
    final threadId = _thread?.id ?? _selectedThreadId;
    if (threadId != null) {
      final snapshot = composerController.snapshot();
      _autosaveManager.scheduleSave(
        threadId: threadId,
        snapshot: snapshot,
      );
    }
    _updateTypingState(composerController.value.text.trim().isNotEmpty);
  }

  void _handleSlashCommand(SlashCommand command) {
    final now = DateTime.now();
    final systemMessage = ChatMessage.text(
      id: 'command-${now.microsecondsSinceEpoch}',
      body: 'Kommando ${command.name} registrert – ${command.description}',
      profileId: _identity.profileId,
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

    if (event is ChatConnectionEvent) {
      switch (event.state) {
        case ChatConnectionState.connected:
          final changed = !_realtimeConnected;
          _realtimeConnected = true;
          _updateOffline(false);
          _markExistingMessagesRead();
          if (changed) {
            notifyListeners();
          }
          break;
        case ChatConnectionState.reconnecting:
        case ChatConnectionState.connecting:
          final wasConnected = _realtimeConnected;
          _realtimeConnected = false;
          _stopTypingActivity();
          if (wasConnected) {
            notifyListeners();
          }
          break;
        case ChatConnectionState.disconnected:
          final wasConnected = _realtimeConnected;
          _realtimeConnected = false;
          _stopTypingActivity();
          if (wasConnected) {
            notifyListeners();
          }
          break;
      }
      return;
    }

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
    if (event.profileId == _identity.profileId) {
      return;
    }

    final index =
        _messages.indexWhere((message) => message.id == event.messageId);
    if (index < 0) {
      return;
    }

    final message = _messages[index];
    if (message.profileId != _identity.profileId) {
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
    if (message.profileId == _identity.profileId) return;
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
    for (final message in _messages) {
      if (message.profileId != _identity.profileId) {
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
    _autosaveManager.dispose();
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

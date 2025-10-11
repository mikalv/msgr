import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/features/chat/models/chat_message.dart';
import 'package:messngr/features/chat/models/chat_thread.dart';
import 'package:messngr/features/chat/models/reaction_aggregate.dart';
import 'package:messngr/features/chat/state/chat_cache_repository.dart';
import 'package:messngr/features/chat/state/chat_view_model.dart';
import 'package:messngr/features/chat/widgets/chat_composer.dart';
import 'package:messngr/services/api/chat_api.dart';
import 'package:messngr/services/api/chat_realtime_event.dart';
import 'package:messngr/services/api/chat_socket.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatViewModel realtime integration', () {
    late _MockRealtime realtime;
    late _StubChatApi api;
    late InMemoryChatCacheStore cache;
    late _FakeConnectivity connectivity;
    late ChatViewModel viewModel;
    late ChatMessage remoteMessage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      realtime = _MockRealtime();
      remoteMessage = ChatMessage.text(
        id: 'msg-remote-1',
        body: 'Hei fra venn',
        profileId: 'profile-remote',
        profileName: 'Buddy',
        profileMode: 'private',
        status: 'sent',
        sentAt: DateTime.now(),
        insertedAt: DateTime.now(),
      );
      api = _StubChatApi(initialMessages: [remoteMessage]);
      cache = InMemoryChatCacheStore();
      connectivity = _FakeConnectivity();
      viewModel = ChatViewModel(
        api: api,
        realtime: realtime,
        cache: cache,
        connectivity: connectivity,
        composer: ChatComposerController(),
      );
      await viewModel.bootstrap();
      await _pump();
    });

    tearDown(() async {
      viewModel.dispose();
      await realtime.dispose();
    });

    test('applies reaction, pinned, typing, deletion and read events', () async {
      final aggregate = ReactionAggregate(
        emoji: '👍',
        count: 1,
        profileIds: const ['profile-remote'],
      );

      realtime.emit(
        ChatReactionEvent(
          messageId: remoteMessage.id,
          emoji: '👍',
          profileId: 'profile-remote',
          isAddition: true,
          aggregates: [aggregate],
        ),
      );
      await _pump();

      expect(viewModel.reactionsFor(remoteMessage.id).first.count, equals(1));

      final pinnedAt = DateTime.now();
      realtime.emit(
        ChatPinnedEvent(
          messageId: remoteMessage.id,
          pinnedById: 'profile-remote',
          pinnedAt: pinnedAt,
          isPinned: true,
        ),
      );
      await _pump();

      expect(viewModel.pinnedNotifier.isPinned(remoteMessage.id), isTrue);

      realtime.emit(
        ChatTypingEvent(
          profileId: 'profile-remote',
          profileName: 'Buddy',
          isTyping: true,
          expiresAt: DateTime.now().add(const Duration(seconds: 5)),
        ),
      );
      await _pump();
      expect(
        viewModel.typingNotifier.activeByThread['root']?.map((p) => p.profileId),
        contains('profile-remote'),
      );

      realtime.emit(
        const ChatTypingEvent(
          profileId: 'profile-remote',
          profileName: 'Buddy',
          isTyping: false,
        ),
      );
      await _pump();
      expect(viewModel.typingNotifier.activeByThread['root'] ?? const [], isEmpty);

      realtime.emit(
        ChatMessageDeletedEvent(
          messageId: remoteMessage.id,
          deletedAt: DateTime.now(),
        ),
      );
      await _pump();
      expect(
        viewModel.messages.firstWhere((message) => message.id == remoteMessage.id).isDeleted,
        isTrue,
      );

      final selfProfileId = viewModel.identity!.profileId;
      final ownMessage = ChatMessage.text(
        id: 'msg-own-1',
        body: 'Min melding',
        profileId: selfProfileId,
        profileName: 'Meg',
        profileMode: 'private',
        status: 'sent',
        sentAt: DateTime.now(),
        insertedAt: DateTime.now(),
      );
      realtime.emit(ChatMessageEvent(ownMessage));
      await _pump();

      realtime.emit(
        ChatReadEvent(
          profileId: 'profile-remote',
          messageId: ownMessage.id,
          readAt: DateTime.now(),
        ),
      );
      await _pump();

      expect(
        viewModel.messages.firstWhere((message) => message.id == ownMessage.id).status,
        equals('read'),
      );

      final freshRemote = ChatMessage.text(
        id: 'msg-remote-2',
        body: 'Ny melding',
        profileId: 'profile-remote',
        profileName: 'Buddy',
        profileMode: 'private',
        status: 'sent',
        sentAt: DateTime.now(),
        insertedAt: DateTime.now(),
      );
      realtime.emit(ChatMessageEvent(freshRemote));
      await _pump();
      expect(realtime.markReadCalls, greaterThan(0));
    });

    test('sends realtime commands for reactions, pins and typing', () async {
      realtime.resetCounters();
      final messageId = remoteMessage.id;

      viewModel.recordReaction(messageId, '🔥');
      await _pump();
      expect(realtime.addReactionCalls, equals(1));

      await viewModel.requestPinMessage(messageId);
      expect(realtime.pinCalls, equals(1));

      await viewModel.requestUnpinMessage(messageId);
      expect(realtime.unpinCalls, equals(1));

      viewModel.composerController.setText('hei');
      await _pump();
      expect(realtime.startTypingCalls, equals(1));

      viewModel.composerController.setText('');
      await _pump();
      expect(realtime.stopTypingCalls, equals(1));
    });
  });
}

Future<void> _pump() async {
  await Future<void>.delayed(Duration.zero);
}

class _StubChatApi extends ChatApi {
  _StubChatApi({required List<ChatMessage> initialMessages})
      : _messages = List<ChatMessage>.from(initialMessages);

  final List<ChatMessage> _messages;
  int _counter = 0;

  ChatThread get _thread => const ChatThread(
        id: 'conversation-test',
        participantNames: ['Demo', 'Buddy'],
        kind: ChatThreadKind.direct,
      );

  @override
  Future<AccountIdentity> createAccount(String displayName, {String? email}) async {
    _counter += 1;
    return AccountIdentity(
      accountId: 'acc-$_counter',
      profileId: 'profile-$_counter',
    );
  }

  @override
  Future<ChatThread> ensureDirectConversation({
    required AccountIdentity current,
    required String targetProfileId,
  }) async {
    return _thread;
  }

  @override
  Future<List<ChatThread>> listConversations({required AccountIdentity current}) async {
    return [_thread];
  }

  @override
  Future<List<ChatMessage>> fetchMessages({
    required AccountIdentity current,
    required String conversationId,
    int limit = 50,
  }) async {
    return List<ChatMessage>.from(_messages);
  }

  @override
  Future<ChatMessage> sendMessage({
    required AccountIdentity current,
    required String conversationId,
    required String body,
  }) async {
    final message = ChatMessage.text(
      id: 'msg-api-${_messages.length + 1}',
      body: body,
      profileId: current.profileId,
      profileName: 'Meg',
      profileMode: 'private',
      status: 'sent',
      sentAt: DateTime.now(),
      insertedAt: DateTime.now(),
    );
    _messages.add(message);
    return message;
  }
}

class _MockRealtime implements ChatRealtime {
  final StreamController<ChatRealtimeEvent> _controller =
      StreamController<ChatRealtimeEvent>.broadcast();

  bool _connected = false;
  bool _disposed = false;
  int addReactionCalls = 0;
  int pinCalls = 0;
  int unpinCalls = 0;
  int markReadCalls = 0;
  int startTypingCalls = 0;
  int stopTypingCalls = 0;

  @override
  Stream<ChatRealtimeEvent> get events => _controller.stream;

  @override
  Stream<ChatMessage> get messages =>
      _controller.stream.whereType<ChatMessageEvent>().map((event) => event.message);

  @override
  bool get isConnected => _connected && !_disposed;

  @override
  Future<void> connect({
    required AccountIdentity identity,
    required String conversationId,
  }) async {
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _controller.close();
  }

  @override
  Future<ChatMessage> send(String body) async {
    throw UnimplementedError('send is not exercised in these tests');
  }

  void emit(ChatRealtimeEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  void resetCounters() {
    addReactionCalls = 0;
    pinCalls = 0;
    unpinCalls = 0;
    startTypingCalls = 0;
    stopTypingCalls = 0;
  }

  @override
  Future<void> startTyping({String? threadId}) async {
    startTypingCalls += 1;
  }

  @override
  Future<void> stopTyping({String? threadId}) async {
    stopTypingCalls += 1;
  }

  @override
  Future<void> markRead(String messageId) async {
    markReadCalls += 1;
  }

  @override
  Future<void> addReaction(String messageId, String emoji, {Map<String, dynamic>? metadata}) async {
    addReactionCalls += 1;
  }

  @override
  Future<void> removeReaction(String messageId, String emoji) async {}

  @override
  Future<void> pinMessage(String messageId, {Map<String, dynamic>? metadata}) async {
    pinCalls += 1;
  }

  @override
  Future<void> unpinMessage(String messageId) async {
    unpinCalls += 1;
  }
}

class _FakeConnectivity extends Connectivity {
  _FakeConnectivity({this.result = ConnectivityResult.wifi});

  final ConnectivityResult result;
  final StreamController<ConnectivityResult> _controller =
      StreamController<ConnectivityResult>.broadcast();

  @override
  Future<ConnectivityResult> checkConnectivity() async => result;

  @override
  Stream<ConnectivityResult> get onConnectivityChanged => _controller.stream;
}

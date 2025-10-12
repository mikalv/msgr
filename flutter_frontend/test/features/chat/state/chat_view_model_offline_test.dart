import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/features/chat/models/chat_message.dart';
import 'package:messngr/features/chat/models/chat_thread.dart';
import 'package:messngr/features/chat/state/chat_cache_repository.dart';
import 'package:messngr/features/chat/state/chat_view_model.dart';
import 'package:messngr/features/chat/widgets/chat_composer.dart';
import 'package:messngr/services/api/chat_api.dart';
import 'package:messngr/services/api/contact_api.dart';
import 'package:messngr/services/api/chat_realtime_event.dart';
import 'package:messngr/services/api/chat_socket.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatViewModel offline', () {
    test('falls back to cache when offline', () async {
      final cache = InMemoryChatCacheStore();
      final thread = ChatThread(
        id: 'thread-1',
        participantNames: const ['Demo'],
        kind: ChatThreadKind.direct,
      );
      final message = ChatMessage.text(
        id: 'msg-1',
        body: 'Cached melding',
        profileId: 'profile-1',
        profileName: 'Demo',
        profileMode: 'private',
        status: 'sent',
      );
      await cache.saveThreads([thread]);
      await cache.saveMessages(thread.id, [message]);

      SharedPreferences.setMockInitialValues({});
      final connectivity = _FakeConnectivity(initial: ConnectivityResult.none);
      final api = _FakeChatApi(thread: thread, message: message);
      final identity = AccountIdentity(accountId: 'acc-1', profileId: 'profile-1');
      final viewModel = ChatViewModel(
        identity: identity,
        api: api,
        realtime: _FakeRealtime(),
        cache: cache,
        connectivity: connectivity,
        composer: ChatComposerController(),
        contacts: _FakeContactApi(),
      );

      await viewModel.bootstrap();

      expect(viewModel.isOffline, isTrue);
      expect(viewModel.messages, isNotEmpty);
      expect(viewModel.messages.first.body, 'Cached melding');
    });
  });
}

class _FakeChatApi extends ChatApi {
  _FakeChatApi({required this.thread, required this.message});

  final ChatThread thread;
  final ChatMessage message;

  @override
  Future<ChatThread> ensureDirectConversation({
    required AccountIdentity current,
    required String targetProfileId,
  }) async {
    return thread;
  }

  @override
  Future<List<ChatThread>> listConversations({required AccountIdentity current}) async {
    return [thread];
  }

  @override
  Future<List<ChatMessage>> fetchMessages({
    required AccountIdentity current,
    required String conversationId,
    int limit = 50,
  }) async {
    throw ApiException(503, 'offline');
  }

  @override
  Future<ChatMessage> sendMessage({
    required AccountIdentity current,
    required String conversationId,
    required String body,
  }) async {
    return message;
  }
}

class _FakeRealtime implements ChatRealtime {
  @override
  bool get isConnected => false;

  @override
  Stream<ChatRealtimeEvent> get events => const Stream<ChatRealtimeEvent>.empty();

  @override
  Stream<ChatMessage> get messages => const Stream<ChatMessage>.empty();

  @override
  Future<void> connect({required AccountIdentity identity, required String conversationId}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<ChatMessage> send(String body) async {
    throw ChatSocketException('offline');
  }

  @override
  Future<void> startTyping({String? threadId}) async {}

  @override
  Future<void> stopTyping({String? threadId}) async {}

  @override
  Future<void> markRead(String messageId) async {}

  @override
  Future<void> addReaction(String messageId, String emoji, {Map<String, dynamic>? metadata}) async {}

  @override
  Future<void> removeReaction(String messageId, String emoji) async {}

  @override
  Future<void> pinMessage(String messageId, {Map<String, dynamic>? metadata}) async {}

  @override
  Future<void> unpinMessage(String messageId) async {}
}

class _FakeConnectivity extends Connectivity {
  _FakeConnectivity({required this.initial});

  final ConnectivityResult initial;
  final StreamController<ConnectivityResult> _controller =
      StreamController<ConnectivityResult>.broadcast();

  @override
  Future<ConnectivityResult> checkConnectivity() async => initial;

  @override
  Stream<ConnectivityResult> get onConnectivityChanged => _controller.stream;
}

class _FakeContactApi extends ContactApi {
  @override
  Future<List<KnownContactMatch>> lookupKnownContacts({
    required AccountIdentity current,
    required List<ContactImportEntry> targets,
  }) async {
    return const [];
  }
}

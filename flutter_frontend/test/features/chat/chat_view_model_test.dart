import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/features/chat/models/chat_message.dart';
import 'package:messngr/features/chat/models/chat_thread.dart';
import 'package:messngr/features/chat/state/chat_view_model.dart';
import 'package:messngr/services/api/chat_api.dart';
import 'package:messngr/services/api/chat_socket.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StubChatApi implements ChatApi {
  StubChatApi();

  final List<ChatMessage> messages = [];
  final ChatThread thread = const ChatThread(
    id: 'conversation-1',
    participantNames: ['Demo', 'Buddy'],
  );
  int _counter = 0;

  @override
  Future<AccountIdentity> createAccount(String displayName, {String? email}) async {
    _counter += 1;
    return AccountIdentity(
      accountId: 'account-$_counter',
      profileId: 'profile-$_counter',
    );
  }

  @override
  Future<ChatThread> ensureDirectConversation({
    required AccountIdentity current,
    required String targetProfileId,
  }) async {
    return thread;
  }

  @override
  Future<List<ChatMessage>> fetchMessages({
    required AccountIdentity current,
    required String conversationId,
    int limit = 50,
  }) async {
    return messages;
  }

  @override
  Future<ChatMessage> sendMessage({
    required AccountIdentity current,
    required String conversationId,
    required String body,
  }) async {
    final message = ChatMessage.text(
      id: 'msg-${messages.length + 1}',
      body: body,
      profileId: current.profileId,
      profileName: 'Deg',
      profileMode: 'private',
      status: 'sent',
      sentAt: DateTime.now(),
      insertedAt: DateTime.now(),
    );
    messages.add(message);
    return message;
  }
}

class StubRealtime implements ChatRealtime {
  final StreamController<ChatMessage> _controller =
      StreamController<ChatMessage>.broadcast();

  bool wasConnected = false;
  bool _isConnected = false;
  AccountIdentity? identity;
  String? conversationId;
  final List<String> sentBodies = [];

  @override
  Stream<ChatMessage> get messages => _controller.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> connect({
    required AccountIdentity identity,
    required String conversationId,
  }) async {
    this.identity = identity;
    this.conversationId = conversationId;
    wasConnected = true;
    _isConnected = true;
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }

  @override
  Future<ChatMessage> send(String body) async {
    sentBodies.add(body);

    final message = ChatMessage.text(
      id: 'ws-${sentBodies.length}',
      body: body,
      profileId: identity?.profileId ?? 'profile-self',
      profileName: 'Deg',
      profileMode: 'private',
      status: 'sent',
      sentAt: DateTime.now(),
      insertedAt: DateTime.now(),
    );

    if (!_controller.isClosed) {
      _controller.add(message);
    }

    return message;
  }

  void emit(ChatMessage message) {
    if (!_controller.isClosed) {
      _controller.add(message);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('bootstrap creates identities and loads messages', () async {
    final api = StubChatApi();
    api.messages.add(ChatMessage.text(
      id: 'initial',
      body: 'Hei der!',
      profileId: 'profile-peer',
      profileName: 'Buddy',
      profileMode: 'private',
      status: 'sent',
      sentAt: DateTime.now(),
      insertedAt: DateTime.now(),
    ));

    final realtime = StubRealtime();
    final viewModel = ChatViewModel(api: api, realtime: realtime);
    await viewModel.bootstrap();

    expect(viewModel.identity, isNotNull);
    expect(viewModel.thread, equals(api.thread));
    expect(viewModel.messages, isNotEmpty);
    expect(realtime.wasConnected, isTrue);
    expect(realtime.conversationId, equals(api.thread.id));
  });

  test('sendMessage forwards to api and updates timeline', () async {
    final api = StubChatApi();
    final realtime = StubRealtime();
    final viewModel = ChatViewModel(api: api, realtime: realtime);
    await viewModel.bootstrap();

    await viewModel.sendMessage('Hallo verden');

    expect(api.messages.map((m) => m.body), contains('Hallo verden'));
    expect(viewModel.messages.last.body, equals('Hallo verden'));
    expect(realtime.sentBodies, contains('Hallo verden'));
  });

  test('incoming realtime messages are merged into timeline', () async {
    final api = StubChatApi();
    final realtime = StubRealtime();
    final viewModel = ChatViewModel(api: api, realtime: realtime);
    await viewModel.bootstrap();

    final incoming = ChatMessage.text(
      id: 'incoming-1',
      body: 'Hei fra andre',
      profileId: 'peer-profile',
      profileName: 'Buddy',
      profileMode: 'private',
      status: 'sent',
      sentAt: DateTime.now(),
      insertedAt: DateTime.now(),
    );

    realtime.emit(incoming);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.messages.last, equals(incoming));
  });
}

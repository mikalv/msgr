import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/features/chat/models/chat_message.dart';
import 'package:messngr/features/chat/models/chat_thread.dart';
import 'package:messngr/features/chat/state/chat_view_model.dart';
import 'package:messngr/services/api/chat_api.dart';
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
    final message = ChatMessage(
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('bootstrap creates identities and loads messages', () async {
    final api = StubChatApi();
    api.messages.add(ChatMessage(
      id: 'initial',
      body: 'Hei der!',
      profileId: 'profile-peer',
      profileName: 'Buddy',
      profileMode: 'private',
      status: 'sent',
      sentAt: DateTime.now(),
      insertedAt: DateTime.now(),
    ));

    final viewModel = ChatViewModel(api: api);
    await viewModel.bootstrap();

    expect(viewModel.identity, isNotNull);
    expect(viewModel.thread, equals(api.thread));
    expect(viewModel.messages, isNotEmpty);
  });

  test('sendMessage forwards to api and updates timeline', () async {
    final api = StubChatApi();
    final viewModel = ChatViewModel(api: api);
    await viewModel.bootstrap();

    await viewModel.sendMessage('Hallo verden');

    expect(api.messages.map((m) => m.body), contains('Hallo verden'));
    expect(viewModel.messages.last.body, equals('Hallo verden'));
  });
}

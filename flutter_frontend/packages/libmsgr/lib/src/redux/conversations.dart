import 'package:libmsgr/libmsgr.dart';

/// This is used when we get a (one) new conversation from the server.
class OnReceiveNewConversationAction {
  final Conversation conversation;

  OnReceiveNewConversationAction(this.conversation);

  @override
  String toString() {
    return 'OnReceiveNewConversationAction{conversation: $conversation}';
  }
}

/// This is used when we get the whole list of conversations from the server.
class OnReceiveConversationsAction {
  final List<Conversation> conversations;

  OnReceiveConversationsAction({required this.conversations});

  @override
  String toString() {
    return 'OnReceiveConversationsAction{conversations: $conversations}';
  }
}

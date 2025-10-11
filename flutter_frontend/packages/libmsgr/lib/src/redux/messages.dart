import 'package:libmsgr/libmsgr.dart';

/// This is used when we get a (one) new message from the server.
class OnReceiveMessageAction {
  final MMessage msg;

  OnReceiveMessageAction({required this.msg});

  @override
  String toString() {
    return 'OnReceiveMessageAction{msg: $msg}';
  }
}

/// This is used when we get the whole list of messages from the server.
class OnReceiveMessagesAction {
  final List<MMessage> messages;

  OnReceiveMessagesAction({required this.messages});

  @override
  String toString() {
    return 'OnReceiveMessagesAction{messages: $messages}';
  }
}

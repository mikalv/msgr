import 'dart:async';

import 'package:libmsgr/libmsgr.dart';

class SendMessageAction {
  final MMessage msg;
  // This should be called when the server CONFIRMS that the message was sent
  // It's success should dispatch OnSendMessageSuccess and on failure OnSendMessageFailure
  final Completer completer;

  SendMessageAction({required this.msg, required this.completer});

  @override
  String toString() {
    return 'SendMessageAction{msg: $msg}';
  }
}

class OnSendMessageSuccessAction {
  final MMessage msg;
  final dynamic serverResponse;

  OnSendMessageSuccessAction({required this.msg, required this.serverResponse});

  @override
  String toString() {
    return 'OnSendMessageSuccessAction{msg: $msg, serverResponse: $serverResponse}';
  }
}

class OnSendMessageFailureAction {
  final MMessage msg;
  final dynamic serverResponse;

  OnSendMessageFailureAction({required this.msg, required this.serverResponse});

  @override
  String toString() {
    return 'OnSendMessageFailureAction{msg: $msg, serverResponse: $serverResponse}';
  }
}

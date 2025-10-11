import 'package:libmsgr/libmsgr.dart';
import 'dart:io';

void main() {
  final msg =
      MMessage(content: "Tester", fromProfileID: "123", conversationID: "456");

  dynamic msgStr = msg.toJson();

  print('Hello; $msgStr');

  print('Testing: ${DateTime.now().runtimeType}');
}

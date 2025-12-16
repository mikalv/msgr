import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MessageWidgetTheme extends InheritedTheme {
  final MessageWidgetThemeData data;

  const MessageWidgetTheme({
    super.key,
    required this.data,
    required super.child,
  });

  static MessageWidgetTheme? of(BuildContext context) {
    final messageWidgetTheme =
        context.dependOnInheritedWidgetOfExactType<MessageWidgetTheme>();
    return messageWidgetTheme;
  }

  @override
  bool updateShouldNotify(MessageWidgetTheme oldWidget) {
    return data != oldWidget.data;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return MessageWidgetTheme(data: data, child: child);
  }
}

class MessageWidgetThemeData with Diagnosticable {
  /// Style of the title text
  final TextStyle? titleStyle;

  /// Style of the timestamp text
  final TextStyle? timestampStyle;

  /// Style of the last message text
  final TextStyle? messageTextStyle;

  final TextStyle? senderTextStyle;

  /// Style of the unread message count text
  final TextStyle? unreadMessageCountStyle;

  final BoxDecoration? mainMessageWidgetDecoration;

  MessageWidgetThemeData(
      {this.titleStyle,
      this.timestampStyle,
      this.messageTextStyle,
      this.unreadMessageCountStyle,
      this.mainMessageWidgetDecoration,
      this.senderTextStyle});

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
  }
}

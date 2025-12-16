import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:messngr/config/theme.dart';

class ChannelListViewTheme extends InheritedTheme {
  final ChannelListViewThemeData data;

  const ChannelListViewTheme({
    super.key,
    required this.data,
    required Widget child,
  }) : super(child: child);

  static ChannelListViewTheme? of(BuildContext context) {
    final channelListViewTheme =
        context.dependOnInheritedWidgetOfExactType<ChannelListViewTheme>();
    return channelListViewTheme ?? AppTheme.of(context).channelListViewTheme;
  }

  @override
  bool updateShouldNotify(ChannelListViewTheme oldWidget) {
    return data != oldWidget.data;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return ChannelListViewTheme(data: data, child: child);
  }
}

class ChannelListViewThemeData with Diagnosticable {
  /// Style of the title text
  final TextStyle? titleStyle;

  /// Style of the timestamp text
  final TextStyle? timestampStyle;

  /// Style of the last message text
  final TextStyle? messagePreviewStyle;

  /// Style of the unread message count text
  final TextStyle? unreadMessageCountStyle;

  final TextStyle? mainListHeaderStyle;

  /// Style of the unread message count box
  final BoxDecoration? unreadMessageCountDecoration;

  /// Style of the channel list item
  final BoxDecoration? channelItemDecoration;

  /// Background color
  final Color? backgroundColor;

  /// Primary color
  final Color? primaryColor;

  /// Main box decoration
  final BoxDecoration? decoration;

  /// Margin
  final EdgeInsets? margin;

  /// Padding
  final EdgeInsets? padding;

  ChannelListViewThemeData(
      {this.primaryColor,
      this.titleStyle,
      this.timestampStyle,
      this.messagePreviewStyle,
      this.unreadMessageCountStyle,
      this.channelItemDecoration,
      this.backgroundColor,
      this.unreadMessageCountDecoration,
      this.decoration,
      this.margin,
      this.padding,
      this.mainListHeaderStyle});

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
  }
}

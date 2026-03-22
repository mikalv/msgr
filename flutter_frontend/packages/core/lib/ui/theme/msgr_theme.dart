import 'package:flutter/material.dart';
import 'msgr_color_tokens.dart';
export 'msgr_color_tokens.dart';
export 'msgr_dimensions.dart';

class MsgrTheme extends InheritedWidget {
  const MsgrTheme({
    super.key,
    required this.colors,
    required super.child,
  });

  final MsgrColorTokens colors;

  static MsgrColorTokens of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<MsgrTheme>();
    return widget?.colors ?? MsgrColorTokens.dark;
  }

  static MsgrColorTokens read(BuildContext context) {
    final widget = context.getInheritedWidgetOfExactType<MsgrTheme>();
    return widget?.colors ?? MsgrColorTokens.dark;
  }

  @override
  bool updateShouldNotify(MsgrTheme oldWidget) => colors != oldWidget.colors;
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:messngr/config/theme.dart';

class AppScaffoldTheme extends InheritedTheme {
  final AppScaffoldThemeData data;

  const AppScaffoldTheme({
    required this.data,
    required Widget child,
  }) : super(child: child);

  static AppScaffoldTheme? of(BuildContext context) {
    final appScaffoldTheme =
        context.dependOnInheritedWidgetOfExactType<AppScaffoldTheme>();
    return appScaffoldTheme ?? AppTheme.of(context).appScaffoldTheme;
  }

  @override
  bool updateShouldNotify(AppScaffoldTheme oldWidget) {
    return data != oldWidget.data;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return AppScaffoldTheme(data: data, child: child);
  }
}

class AppScaffoldThemeData with Diagnosticable {
  final Color? backgroundColor;
  final Color? primaryColor;
  final BoxDecoration? decoration;
  final EdgeInsets? margin;

  const AppScaffoldThemeData({
    this.backgroundColor,
    this.primaryColor,
    this.decoration,
    this.margin,
  });
}

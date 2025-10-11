import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:messngr/config/app_constants.dart';

class _MacOSTitlebarSafeArea extends StatefulWidget {
  final Widget child;

  const _MacOSTitlebarSafeArea({required this.child});

  @override
  State<_MacOSTitlebarSafeArea> createState() => _MacOSTitlebarSafeAreaState();
}

class _MacOSTitlebarSafeAreaState extends State<_MacOSTitlebarSafeArea> {
  int _titlebarHeight = 0;

  /// Updates the height of the titlebar, if necessary.
  Future<void> _updateTitlebarHeight() async {
    const newTitlebarHeight =
        assumedMacOSTitleBarHeight; //await windowManager.getTitleBarHeight();
    //print('Window titlebar height is :::::::::::::: $newTitlebarHeight');
    if (_titlebarHeight != newTitlebarHeight) {
      setState(() {
        _titlebarHeight = newTitlebarHeight;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _updateTitlebarHeight();

    return Padding(
      padding: EdgeInsets.only(top: _titlebarHeight.toDouble()),
      child: widget.child,
    );
  }
}

class TitlebarSafeArea extends StatelessWidget {
  final Widget child;

  /// A widget that provides a safe area for its child.
  ///
  /// The safe area is the area of the window that is not covered by the
  /// window's title bar. This widget has no effect when the full-size content
  /// view is disabled or when the app is running on a platform other than
  /// macOS.
  ///
  /// Example:
  /// ```dart
  /// TitlebarSafeArea(
  ///  child: Text('Hello World'),
  /// )
  /// ```
  const TitlebarSafeArea({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) return child;

    return _MacOSTitlebarSafeArea(child: child);
  }
}

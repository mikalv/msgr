import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class BaseScaffold extends StatefulWidget {
  final bool primary;
  final bool drawerEnableOpenDragGesture;
  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final NavigationBar? bottomNavigationBar;
  final DragStartBehavior drawerDragStartBehavior;
  const BaseScaffold(
      {super.key,
      required this.child,
      this.appBar,
      this.drawer,
      this.primary = true,
      this.drawerEnableOpenDragGesture = true,
      this.bottomNavigationBar,
      this.drawerDragStartBehavior = DragStartBehavior.start});

  @override
  State<BaseScaffold> createState() => _BaseScaffoldState();
}

class _BaseScaffoldState extends State<BaseScaffold> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      appBar: widget.appBar,
      drawer: widget.drawer,
      primary: widget.primary,
      bottomNavigationBar: widget.bottomNavigationBar,
      drawerDragStartBehavior: widget.drawerDragStartBehavior,
      drawerEnableOpenDragGesture: widget.drawerEnableOpenDragGesture,
    );
  }
}

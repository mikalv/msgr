import 'package:flutter/material.dart';

class BottomNavigationBarWidget extends StatelessWidget {
  final List<Widget> children;
  final Widget body;
  const BottomNavigationBarWidget(
      {super.key, required this.children, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: body),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children,
        )
      ],
    );
  }
}

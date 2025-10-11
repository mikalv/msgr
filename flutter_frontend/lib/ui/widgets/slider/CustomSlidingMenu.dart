import 'package:flutter/material.dart';

class CustomSlidingMenu extends StatelessWidget {
  final double sliderMenuOpenSize;
  final Widget sliderMenu;

  const CustomSlidingMenu(
      {super.key, required this.sliderMenuOpenSize, required this.sliderMenu});

  @override
  Widget build(BuildContext context) {
    var container = Container(
      width: sliderMenuOpenSize,
      child: sliderMenu,
    );
    return container;
  }
}

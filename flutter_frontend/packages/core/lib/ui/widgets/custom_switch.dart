/// A custom switch widget that allows toggling between two states with
/// customizable appearance and behavior.
///
/// The [CustomSwitch] widget provides a switch with text labels, colors,
/// and icons for both active and inactive states. It also supports tooltips
/// and custom animations.
///
/// The switch can be customized with the following properties:
///
/// * [value]: The current value of the switch (true for active, false for inactive).
/// * [onChanged]: A callback function that is called when the switch is toggled.
/// * [height]: The height of the switch.
/// * [fontSize]: The font size of the text labels.
/// * [activeColor]: The background color of the switch when it is active.
/// * [inactiveColor]: The background color of the switch when it is inactive.
/// * [activeText]: The text label displayed when the switch is active.
/// * [inactiveText]: The text label displayed when the switch is inactive.
/// * [activeTextColor]: The color of the text label when the switch is active.
/// * [inactiveTextColor]: The color of the text label when the switch is inactive.
/// * [activeThumbColor]: The color of the thumb when the switch is active.
/// * [inactiveThumbColor]: The color of the thumb when the switch is inactive.
/// * [activeTooltip]: The tooltip message displayed when the switch is active.
/// * [inactiveTooltip]: The tooltip message displayed when the switch is inactive.
/// * [activeThumbIcon]: An optional icon displayed inside the thumb when the switch is active.
/// * [inactiveThumbIcon]: An optional icon displayed inside the thumb when the switch is inactive.
///
/// Example usage:
/// ```dart
/// CustomSwitch(
///   value: true,
///   onChanged: (newValue) {
///     // Handle switch toggle
///   },
///   activeText: 'Enabled',
///   inactiveText: 'Disabled',
///   activeColor: Colors.green,
///   inactiveColor: Colors.red,
///   activeThumbIcon: Icon(Icons.check),
///   inactiveThumbIcon: Icon(Icons.close),
/// )
/// ```
import 'dart:math';
import 'package:flutter/material.dart';

class CustomSwitch extends StatefulWidget {
  /// Public properties, set on constructor
  final bool value;
  final double height;
  final double fontSize;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final Color inactiveColor;
  final String activeText;
  final String inactiveText;
  final Color activeTextColor;
  final Color inactiveTextColor;
  final Color activeThumbColor;
  final Color inactiveThumbColor;
  final String activeTooltip;
  final String inactiveTooltip;
  final Widget? activeThumbIcon;
  final Widget? inactiveThumbIcon;

  // Private widgets created from properties in constructor.
  late final Text _activeTextWidget;
  late final Text _inactiveTextWidget;
  late final double _spaceRequiredForText;

  CustomSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.height = 35,
    this.fontSize = 16,
    this.activeColor = Colors.blue,
    this.inactiveColor = Colors.grey,
    this.activeText = 'On',
    this.inactiveText = 'Off',
    this.activeTextColor = Colors.white,
    this.inactiveTextColor = Colors.white,
    this.activeThumbColor = Colors.white,
    this.inactiveThumbColor = Colors.white,
    this.activeTooltip = '',
    this.inactiveTooltip = '',
    this.activeThumbIcon,
    this.inactiveThumbIcon,
  }) {
    /// Create the text widgets so that we can use their size to determine widget
    /// width.
    _activeTextWidget = Text(
      activeText,
      style: TextStyle(
          color: activeTextColor,
          fontWeight: FontWeight.bold,
          fontSize: fontSize),
    );

    _inactiveTextWidget = Text(
      inactiveText,
      style: TextStyle(
          color: inactiveTextColor,
          fontWeight: FontWeight.bold,
          fontSize: fontSize),
    );

    // Get size required for text. Max size of the above
    _spaceRequiredForText = max(_textSize(_activeTextWidget).width,
        _textSize(_inactiveTextWidget).width);
  }

  @override
  State<CustomSwitch> createState() => _CustomSwitchState();

  Size _textSize(Text text) {
    /// Method to get size of text widget
    final TextPainter textPainter = TextPainter(
        text: TextSpan(text: text.data, style: text.style),
        maxLines: 1,
        textDirection: TextDirection.ltr)
      ..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size;
  }
}

class _CustomSwitchState extends State<CustomSwitch>
    with SingleTickerProviderStateMixin {
  late Animation _circleAnimation;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 60));
    _circleAnimation = AlignmentTween(
            begin: widget.value ? Alignment.centerRight : Alignment.centerLeft,
            end: widget.value ? Alignment.centerLeft : Alignment.centerRight)
        .animate(CurvedAnimation(
            parent: _animationController, curve: Curves.linear));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return GestureDetector(
            onTap: () {
              if (_animationController.isCompleted) {
                _animationController.reverse();
              } else {
                _animationController.forward();
              }
              widget.onChanged(!widget.value);
            },
            child: Tooltip(
              message:
                  widget.value ? widget.activeTooltip : widget.inactiveTooltip,
              child: Container(
                // text size + thumb size (widget height) + 3 lots of padding,
                // both edges and padding between thumb and text
                width: widget._spaceRequiredForText + widget.height + 12,
                height: widget.height,
                margin: const EdgeInsets.only(
                    top: 4.0, bottom: 4.0, right: 4.0, left: 4.0),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50.0),
                    color: widget.value
                        ? widget.activeColor
                        : widget.inactiveColor),
                child: Padding(
                  padding: const EdgeInsets.only(
                      top: 4.0, bottom: 4.0, right: 4.0, left: 4.0),
                  child: Row(
                    mainAxisAlignment: widget.value
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      widget.value
                          ? Padding(
                              padding:
                                  const EdgeInsets.only(left: 4.0, right: 4.0),
                              child: widget._activeTextWidget,
                            )
                          : Container(),
                      Align(
                        alignment: _circleAnimation.value,
                        child: Container(
                            alignment: Alignment.center,
                            width: widget.height - 8,
                            height: widget.height - 8,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.value
                                    ? widget.activeThumbColor
                                    : widget.inactiveThumbColor),
                            child: widget.value
                                ? widget.activeThumbIcon ?? Container()
                                : widget.inactiveThumbIcon ?? Container()),
                      ),
                      !widget.value
                          ? Padding(
                              padding:
                                  const EdgeInsets.only(left: 4.0, right: 5.0),
                              child: widget._inactiveTextWidget,
                            )
                          : Container(),
                    ],
                  ),
                ),
              ),
            ));
      },
    );
  }
}

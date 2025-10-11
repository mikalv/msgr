import 'package:flutter/material.dart';
import 'package:messngr/ui/widgets/dropdown_search/src/properties/icon_button_props.dart';

class CustomIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconButtonProps props;
  final Widget? icon;

  const CustomIconButton({
    super.key,
    required this.props,
    this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      style: props.style,
      isSelected: props.isSelected,
      selectedIcon: props.selectedIcon,
      onPressed: onPressed,
      icon: icon ?? props.icon,
      constraints: props.constraints,
      hoverColor: props.hoverColor,
      highlightColor: props.highlightColor,
      splashColor: props.splashColor,
      color: props.color,
      focusColor: props.focusColor,
      iconSize: props.iconSize,
      padding: props.padding,
      splashRadius: props.splashRadius,
      alignment: props.alignment,
      autofocus: props.autofocus,
      disabledColor: props.disabledColor,
      enableFeedback: props.enableFeedback,
      focusNode: props.focusNode,
      mouseCursor: props.mouseCursor,
      tooltip: props.tooltip,
      visualDensity: props.visualDensity,
    );
  }
}

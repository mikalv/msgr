import 'package:flutter/cupertino.dart';
import 'package:messngr/ui/widgets/dropdown_search/src/properties/scroll_props.dart';

class CustomSingleScrollView extends StatelessWidget {
  final ScrollProps scrollProps;
  final Widget child;

  const CustomSingleScrollView({
    super.key,
    this.scrollProps = const ScrollProps(),
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollProps.controller,
      padding: scrollProps.padding,
      clipBehavior: scrollProps.clipBehavior,
      dragStartBehavior: scrollProps.dragStartBehavior,
      hitTestBehavior: scrollProps.hitTestBehavior,
      keyboardDismissBehavior: scrollProps.keyboardDismissBehavior,
      physics: scrollProps.physics,
      scrollDirection: scrollProps.scrollDirection,
      reverse: scrollProps.reverse,
      primary: scrollProps.primary,
      child: child,
    );
  }
}

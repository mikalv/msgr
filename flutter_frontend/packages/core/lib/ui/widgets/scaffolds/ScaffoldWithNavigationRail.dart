import 'package:flutter/material.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/ui/widgets/left_drawer/left_drawer.dart';
import 'package:messngr/ui/widgets/scaffolds/base_scaffold.dart';

class ScaffoldWithNavigationRail extends StatelessWidget {
  const ScaffoldWithNavigationRail({
    super.key,
    required this.body,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });
  final Widget body;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    List<NavigationRailDestination> navList = AppNavigation.navBarItems
        .map((obj) => NavigationRailDestination(
            icon: obj['icon'] as Icon, label: Text(obj['label'] as String)))
        .toList();
    var row = Row(
      children: [
        // Fixed navigation rail on the left (start)
        NavigationRail(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          labelType: NavigationRailLabelType.all,
          destinations: navList,
        ),
        const VerticalDivider(thickness: 1, width: 1),
        // Main content on the right (end)
        Expanded(
          child: body,
        ),
      ],
    );
    return BaseScaffold(
      drawer: const LeftDrawer(),
      child: row,
    );
  }
}

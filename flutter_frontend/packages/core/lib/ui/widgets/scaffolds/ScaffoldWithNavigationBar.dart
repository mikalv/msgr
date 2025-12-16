import 'package:flutter/material.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/ui/widgets/left_drawer/left_drawer.dart';
import 'package:messngr/ui/widgets/scaffolds/base_scaffold.dart';

class ScaffoldWithNavigationBar extends StatelessWidget {
  const ScaffoldWithNavigationBar({
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
    List<NavigationDestination> navList = AppNavigation.navBarItems
        .map((obj) => NavigationDestination(
            icon: obj['icon'] as Icon, label: obj['label'] as String))
        .toList();
    return BaseScaffold(
      drawer: const LeftDrawer(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        destinations: navList,
        onDestinationSelected: onDestinationSelected,
      ),
      child: body,
    );
  }
}

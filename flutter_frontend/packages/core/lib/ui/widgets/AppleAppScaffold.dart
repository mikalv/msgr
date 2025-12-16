import 'package:flutter/cupertino.dart';

class AppleAppScaffold extends StatelessWidget {
  final Widget body;
  final bool hasDrawer;

  const AppleAppScaffold(
      {super.key, required this.body, this.hasDrawer = false});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.star_fill),
              label: 'Favorites',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.clock_solid),
              label: 'Recents',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.person_alt_circle_fill),
              label: 'Contacts',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.circle_grid_3x3_fill),
              label: 'Keypad',
            ),
          ],
        ),
        //body: body,
        //bottomNavigationBar: const MsgrBottomNavBar(),
        tabBuilder: (BuildContext context, int index) {
          return CupertinoTabView(
            builder: (BuildContext context) {
              return Center(
                child: Text('Content of tab $index'),
              );
            },
          );
        });
  }
}

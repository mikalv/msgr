import 'package:flutter/material.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/navigation/navigation_actions.dart';
import 'package:messngr/ui/widgets/CategorySelector.dart';
import 'package:messngr/ui/widgets/RecentChats.dart';
import 'package:messngr/utils/flutter_redux.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final store = StoreProvider.of<AppState>(context);
    return Column(
      children: <Widget>[
        const CategorySelector(),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).hintColor,
            ),
            child: Column(
              children: <Widget>[
                Row(
                  children: [
                    IconButton(
                        onPressed: () {
                          StoreProvider.of<AppState>(context).dispatch(
                              NavigateShellToNewRouteAction(
                                  route: AppNavigation.settingsPath));
                        },
                        icon: const Icon(Icons.settings)),
                    IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_reaction_outlined),
                      onPressed: () {
                        StoreProvider.of<AppState>(context).dispatch(
                            NavigateShellToNewRouteAction(
                                route: AppNavigation.inviteMemberPath));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_comment),
                      onPressed: () {
                        StoreProvider.of<AppState>(context).dispatch(
                            NavigateShellToNewRouteAction(
                                route: AppNavigation.createRoomPath +
                                    store.state.authState.currentTeamName!,
                                kUsePush: true));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.maps_ugc),
                      onPressed: () {
                        StoreProvider.of<AppState>(context).dispatch(
                            NavigateShellToNewRouteAction(
                                route: AppNavigation.createConversationPath +
                                    store.state.authState.currentTeamName!,
                                kUsePush: true));
                      },
                    ),
                  ],
                ),
                const RecentChats(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/authentication/auth_actions.dart';
import 'package:messngr/redux/navigation/navigation_actions.dart';
import 'package:messngr/utils/flutter_redux.dart';

class SelectCurrentTeamScreen extends StatelessWidget {
  const SelectCurrentTeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final teamListe = StoreProvider.of<AppState>(context)
        .state
        .authState
        .teams
        .map<Widget>(
          (e) => ListTile(
            title: Text(e.name),
            subtitle: Text('domain: ${e.name}.$apiServer'),
            tileColor: Colors.blue,
            minVerticalPadding: 20,
            horizontalTitleGap: 100,
            onTap: () {
              var hm = SelectAndAuthWithTeamAction(teamName: e.name);
              print('Debug: ${hm.toString()}');
              StoreProvider.of<AppState>(context).dispatch(hm);
            },
          ),
        )
        .toList();
    if (teamListe.isEmpty) {
      teamListe.add(const ListTile(
          title: Text(
              'It doesn\'t seem like you are member of any teams. Maybe you want to create one?')));
    }
    return Scaffold(
      appBar: AppBar(
        actions: const [],
        automaticallyImplyLeading: false,
        elevation: 3.0,
        centerTitle: true,
        title: const Text(
          'Select current team',
          style: TextStyle(
            fontSize: 25,
          ),
        ),
        backgroundColor: Colors.purple,
      ),
      body: Center(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                child: Column(
                  children: [
                    const Text(
                      'Select team',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 32),
                    ),
                    ...teamListe,
                    ElevatedButton(
                      child: const Text('Create new team'),
                      onPressed: () => {
                        StoreProvider.of<AppState>(context).dispatch(
                            NavigateToNewRouteAction(
                                route: AppNavigation.registerTeamPath))
                      },
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

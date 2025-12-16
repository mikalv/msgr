import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/providers/auth_provider.dart';

class SelectCurrentTeamScreen extends ConsumerWidget {
  const SelectCurrentTeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teams = ref.watch(authProvider).teams;

    final teamListe = teams
        .map<Widget>(
          (e) => ListTile(
            title: Text(e.name),
            subtitle: Text('domain: ${e.name}.$apiServer'),
            tileColor: Colors.blue,
            minVerticalPadding: 20,
            horizontalTitleGap: 100,
            onTap: () async {
              // TODO: Implement selectAndAuthWithTeam in authProvider
              await ref.read(authProvider.notifier).selectTeam(e);
              if (!context.mounted) return;
              context.go(AppNavigation.dashboardPath);
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
                      onPressed: () {
                        context.push(AppNavigation.registerTeamPath);
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

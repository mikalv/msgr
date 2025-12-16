import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/providers/auth_provider.dart';
import 'package:messngr/providers/websocket_provider.dart';

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
              try {
                // Select team and get access token
                await ref.read(authProvider.notifier).selectTeam(e);

                // Connect to WebSocket
                await ref.read(webSocketProvider.notifier).connect();

                if (!context.mounted) return;
                context.go(AppNavigation.dashboardPath);
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to connect: $error')),
                );
              }
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

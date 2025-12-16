import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messngr/providers/auth_provider.dart';
import 'package:messngr/ui/pages/invite_page/invite_page.dart';

class LeftDrawer extends ConsumerWidget {
  const LeftDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    final teams = authState.teams;
    final activeTeamID = authState.currentTeam?.id;

    final List<Widget> teamListTile = teams.map((team) {
      return ListTile(
        title: Text(team.name),
        selectedColor: (team.id == activeTeamID)
            ? const Color.fromARGB(255, 189, 10, 118)
            : Colors.white,
        selected: (team.id == activeTeamID) ? true : false,
        selectedTileColor:
            (team.id == activeTeamID) ? Colors.teal : Colors.white,
        onTap: () {
          print('hmm');
        },
      );
    }).toList();

    return Drawer(
      child: ListView(
        padding: const EdgeInsets.only(top: 0.0),
        children: [
          UserAccountsDrawerHeader(
            accountName:
                Text(authState.currentProfile?.username ?? ''),
            accountEmail: Text(
                authState.currentUser?.identifier ?? 'Faen da'),
            decoration:
                const BoxDecoration(color: Color.fromARGB(255, 135, 43, 73)),
          ),
          ...teamListTile,
          Container(
            height: 40,
            padding: const EdgeInsets.only(bottom: 0.0),
            color: const Color.fromARGB(255, 82, 31, 192),
            child: const Center(
              child: Text(
                'Footer',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

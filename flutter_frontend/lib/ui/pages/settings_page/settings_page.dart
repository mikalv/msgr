import 'package:flutter/material.dart';
import 'package:messngr/features/bridges/pages/bridge_hub_page.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/authentication/auth_actions.dart';
import 'package:messngr/utils/flutter_redux.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Innstillinger'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          Text('Konto', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.logout,
            title: 'Logg ut',
            subtitle: 'Fjern denne enheten fra kontoen din.',
            onTap: () {
              StoreProvider.of<AppState>(context).dispatch(LogOutAction());
            },
          ),
          const SizedBox(height: 32),
          Text('Integrasjoner', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.hub,
            title: 'Tilkoblede broer',
            subtitle:
                'Velg hvilke nettverk du vil koble til og følg den enkle veiviseren.',
            onTap: () {
              Navigator.of(context).push(BridgeHubPage.route(context));
            },
          ),
          _SettingsTile(
            icon: Icons.notifications_active_outlined,
            title: 'Varsler',
            subtitle: 'Tilpass varsler for meldinger, samtaler og møter.',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Varselinnstillinger kommer snart.'),
                ),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Utseende',
            subtitle: 'Velg lys eller mørk modus, og juster skriftstørrelse.',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tilpasning av utseende er under arbeid.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Icon(icon),
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

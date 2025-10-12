import 'package:flutter/material.dart';
import 'package:messngr/features/bridges/models/bridge_catalog_entry.dart';
import 'package:messngr/features/bridges/pages/bridge_wizard_page.dart';
import 'package:messngr/features/bridges/state/bridge_catalog_controller.dart';
import 'package:messngr/services/api/bridge_api.dart';
import 'package:messngr/services/api/chat_api.dart';
import 'package:provider/provider.dart';

class BridgeHubPage extends StatelessWidget {
  const BridgeHubPage({super.key});

  static Route<void> route(BuildContext context) {
    final identity = Provider.of<AccountIdentity>(context, listen: false);
    return MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => BridgeCatalogController(identity: identity)
          ..load(),
        child: const BridgeHubPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected Bridges'),
      ),
      body: Consumer<BridgeCatalogController>(
        builder: (context, controller, _) {
          if (controller.isLoading && controller.entries.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.error != null && controller.entries.isEmpty) {
            return _BridgeErrorState(
              error: controller.error!,
              onRetry: controller.load,
            );
          }

          final entries = controller.visibleEntries;
          return RefreshIndicator(
            onRefresh: controller.load,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _BridgeFilterChips(
                      activeFilter: controller.filter,
                      onFilterChanged: controller.applyFilter,
                    ),
                  ),
                ),
                if (controller.isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                if (!controller.isLoading && entries.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.signal_cellular_alt,
                              size: 64, color: theme.colorScheme.outline),
                          const SizedBox(height: 16),
                          Text(
                            'Ingen broer å vise her ennå.',
                            style: theme.textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Prøv et annet filter eller trekk for å oppdatere.',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.colorScheme.outline),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final entry = entries[index];
                          return _BridgeCard(
                            entry: entry,
                            onTap: entry.isAvailable
                                ? () => _openWizard(context, entry)
                                : null,
                          );
                        },
                        childCount: entries.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openWizard(BuildContext context, BridgeCatalogEntry entry) async {
    final identity = Provider.of<AccountIdentity>(context, listen: false);
    final api = BridgeApi();

    try {
      final session = await api.startSession(
        current: identity,
        bridgeId: entry.id,
      );
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Provider.value(
            value: identity,
            child: BridgeWizardPage(
              bridge: entry,
              initialSession: session,
              api: api,
            ),
          ),
        ),
      );
    } catch (error, stackTrace) {
      if (!context.mounted) return;
      debugPrint('Failed to start bridge session: $error\n$stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Klarte ikke å starte innloggingen. Prøv igjen senere.'),
        ),
      );
    }
  }
}

class _BridgeFilterChips extends StatelessWidget {
  const _BridgeFilterChips({
    required this.activeFilter,
    required this.onFilterChanged,
  });

  final String activeFilter;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const filters = [
      ('available', 'Tilgjengelig nå'),
      ('linked', 'Allerede koblet'),
      ('coming_soon', 'Kommer snart'),
      ('all', 'Alle broer'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Utforsk broer',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in filters)
              ChoiceChip(
                label: Text(entry.$2),
                selected: activeFilter == entry.$1,
                onSelected: (selected) {
                  if (selected) {
                    onFilterChanged(entry.$1);
                  }
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _BridgeCard extends StatelessWidget {
  const _BridgeCard({required this.entry, this.onTap});

  final BridgeCatalogEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final statusChip = switch (entry.status) {
      'available' => Chip(
          label: const Text('Tilgjengelig'),
          avatar: const Icon(Icons.bolt, size: 18),
          backgroundColor: colorScheme.secondaryContainer,
          labelStyle: theme.textTheme.labelLarge
              ?.copyWith(color: colorScheme.onSecondaryContainer),
        ),
      'coming_soon' => Chip(
          label: const Text('Kommer snart'),
          avatar: const Icon(Icons.hourglass_bottom, size: 18),
          backgroundColor: colorScheme.surfaceVariant,
        ),
      _ => Chip(label: Text(entry.status)),
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    child: Text(entry.displayName.characters.first),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.displayName,
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                            statusChip,
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.description,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final prerequisite in entry.prerequisites)
                    Chip(
                      label: Text(prerequisite),
                      avatar: const Icon(Icons.check_circle, size: 18),
                    ),
                  if (entry.tags.isNotEmpty)
                    for (final tag in entry.tags)
                      Chip(
                        label: Text(tag.toUpperCase()),
                        backgroundColor: colorScheme.tertiaryContainer,
                        labelStyle: theme.textTheme.labelLarge
                            ?.copyWith(color: colorScheme.onTertiaryContainer),
                      ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (entry.isAvailable)
                    FilledButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('Koble til'),
                    )
                  else
                    FilledButton.tonalIcon(
                      onPressed: null,
                      icon: const Icon(Icons.schedule),
                      label: const Text('Snart klar'),
                    ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => _BridgeCapabilitiesDialog(entry: entry),
                      );
                    },
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Detaljer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BridgeCapabilitiesDialog extends StatelessWidget {
  const _BridgeCapabilitiesDialog({required this.entry});

  final BridgeCatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Hva støtter ${entry.displayName}?'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(entry.description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            if (entry.capabilities.isNotEmpty)
              ...entry.capabilities.entries.map((capability) {
                final value = capability.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        capability.key,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value.toString(),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Lukk'),
        ),
      ],
    );
  }
}

class _BridgeErrorState extends StatelessWidget {
  const _BridgeErrorState({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'Klarte ikke å laste brokatalogen.',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Prøv igjen'),
          ),
        ],
      ),
    );
  }
}

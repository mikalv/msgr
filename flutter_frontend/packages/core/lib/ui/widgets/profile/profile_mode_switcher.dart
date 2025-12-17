import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:core/features/auth/auth_gate.dart';
import 'package:core/providers/api_providers.dart';
import 'package:core/providers/auth_provider.dart';
import 'package:core/providers/team_provider.dart';
import 'package:provider/provider.dart' as provider;

class ProfileModeSwitcher extends ConsumerStatefulWidget {
  const ProfileModeSwitcher({
    super.key,
    this.onFilterChanged,
    this.initialFilter,
  });

  final ValueChanged<ProfileMode?>? onFilterChanged;
  final ProfileMode? initialFilter;

  @override
  ConsumerState<ProfileModeSwitcher> createState() => _ProfileModeSwitcherState();
}

class _ProfileModeSwitcherState extends ConsumerState<ProfileModeSwitcher> {
  bool _requestedInitial = false;
  String? _pendingProfileId;
  String? _error;
  ProfileMode? _activeFilter;

  @override
  void initState() {
    super.initState();
    _activeFilter = widget.initialFilter;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_requestedInitial) {
      // TODO: Implement profile refresh via provider
      // final session = Provider.of<AuthSession>(context, listen: false);
      // ref.read(teamProvider.notifier).loadProfiles();
      _requestedInitial = true;
    }
  }

  void _updateFilter(ProfileMode? mode) {
    if (_activeFilter == mode) {
      return;
    }
    setState(() {
      _activeFilter = mode;
    });
    widget.onFilterChanged?.call(mode);
  }

  Future<void> _handleSwitch(
    Profile currentProfile,
    Profile target,
  ) async {
    if (_pendingProfileId == target.id) {
      return;
    }
    if (currentProfile.id == target.id) {
      return;
    }

    final session = provider.Provider.of<AuthSession>(context, listen: false);

    setState(() {
      _pendingProfileId = target.id;
      _error = null;
    });

    try {
      // Use authProvider's switchProfile method
      final api = ref.read(profileApiProvider);
      final result = await api.switchProfile(
        identity: session.identity,
        profileId: target.id,
      );

      // Update session with new identity
      await session.updateIdentity(
        result.identity,
        displayName: result.profile.displayName,
      );

      // Update Riverpod state - this will trigger UI updates automatically
      ref.read(authProvider.notifier).setCurrentProfile(result.profile);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Byttet til ${result.profile.displayName}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Kunne ikke bytte profil: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _pendingProfileId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider);
    final currentProfile = ref.watch(currentProfileProvider);

    if (profiles.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isSwitching = _pendingProfileId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (currentProfile != null)
          _ProfileModeBanner(profile: currentProfile),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: profiles.map((profile) {
            final selected = profile.id == currentProfile?.id;
            final busy = isSwitching && _pendingProfileId == profile.id;
            final icon = _modeIcon(profile.mode, theme);
            return ChoiceChip(
              label: Text(profile.displayName),
              avatar: Icon(icon, size: 18),
              selected: selected,
              onSelected: (busy || currentProfile == null)
                  ? null
                  : (_) => _handleSwitch(currentProfile, profile),
              selectedColor: theme.colorScheme.primary.withOpacity(0.2),
              showCheckmark: false,
            );
          }).toList(),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 12),
        _InboxFilterRow(
          activeFilter: _activeFilter,
          onChanged: _updateFilter,
        ),
      ],
    );
  }
}

class _ProfileModeBanner extends StatelessWidget {
  const _ProfileModeBanner({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _modeColor(profile.mode, theme);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(_modeIcon(profile.mode, theme), color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Aktiv modus: ${profile.mode.localizedName}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxFilterRow extends StatelessWidget {
  const _InboxFilterRow({
    required this.activeFilter,
    required this.onChanged,
  });

  final ProfileMode? activeFilter;
  final ValueChanged<ProfileMode?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        FilterChip(
          label: const Text('Alle innbokser'),
          selected: activeFilter == null,
          onSelected: (_) => onChanged(null),
        ),
        const SizedBox(width: 8),
        for (final mode in [
          ProfileMode.private,
          ProfileMode.work,
          ProfileMode.family,
        ])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(mode.localizedName),
              selected: activeFilter == mode,
              avatar: Icon(
                _modeIcon(mode, theme),
                size: 18,
              ),
              onSelected: (_) => onChanged(mode),
            ),
          ),
      ],
    );
  }
}

IconData _modeIcon(ProfileMode mode, ThemeData theme) {
  switch (mode) {
    case ProfileMode.private:
      return Icons.person_outline_rounded;
    case ProfileMode.work:
      return Icons.work_outline_rounded;
    case ProfileMode.family:
      return Icons.family_restroom_rounded;
    case ProfileMode.unknown:
      return Icons.account_circle_outlined;
  }
}

Color _modeColor(ProfileMode mode, ThemeData theme) {
  switch (mode) {
    case ProfileMode.private:
      return theme.colorScheme.primary;
    case ProfileMode.work:
      return theme.colorScheme.tertiary;
    case ProfileMode.family:
      return theme.colorScheme.secondary;
    case ProfileMode.unknown:
      return theme.colorScheme.outline;
  }
}

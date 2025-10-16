import 'dart:async';

import 'package:flutter/material.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/features/auth/auth_gate.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/profile/profile_actions.dart';
import 'package:messngr/services/api/profile_api.dart';
import 'package:messngr/utils/flutter_redux.dart';
import 'package:provider/provider.dart';
import 'package:redux/redux.dart';

class ProfileModeSwitcher extends StatefulWidget {
  const ProfileModeSwitcher({
    super.key,
    this.onFilterChanged,
    this.initialFilter,
  });

  final ValueChanged<ProfileMode?>? onFilterChanged;
  final ProfileMode? initialFilter;

  @override
  State<ProfileModeSwitcher> createState() => _ProfileModeSwitcherState();
}

class _ProfileModeSwitcherState extends State<ProfileModeSwitcher> {
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
      final session = Provider.of<AuthSession>(context, listen: false);
      StoreProvider.of<AppState>(context).dispatch(
        RefreshProfilesAction(identity: session.identity),
      );
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
    _ProfileSwitcherViewModel viewModel,
    Profile target,
  ) async {
    if (_pendingProfileId == target.id) {
      return;
    }
    if (viewModel.currentProfile?.id == target.id) {
      return;
    }

    final session = Provider.of<AuthSession>(context, listen: false);
    final completer = Completer<ProfileSwitchResult>();
    setState(() {
      _pendingProfileId = target.id;
      _error = null;
    });

    viewModel.onSwitch(session.identity, target.id, completer);

    try {
      final result = await completer.future;
      await session.updateIdentity(
        result.identity,
        displayName: result.profile.displayName,
      );
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
    return StoreConnector<AppState, _ProfileSwitcherViewModel>(
      converter: (store) => _ProfileSwitcherViewModel.fromStore(store),
      distinct: true,
      builder: (context, viewModel) {
        if (viewModel.profiles.isEmpty) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final isSwitching = _pendingProfileId != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (viewModel.currentProfile != null)
              _ProfileModeBanner(profile: viewModel.currentProfile!),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: viewModel.profiles.map((profile) {
                final selected = profile.id == viewModel.currentProfile?.id;
                final busy = isSwitching && _pendingProfileId == profile.id;
                final icon = _modeIcon(profile.mode, theme);
                return ChoiceChip(
                  label: Text(profile.displayName),
                  avatar: Icon(icon, size: 18),
                  selected: selected,
                  onSelected: busy
                      ? null
                      : (_) => _handleSwitch(viewModel, profile),
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
      },
    );
  }
}

class _ProfileSwitcherViewModel {
  _ProfileSwitcherViewModel({
    required this.profiles,
    required this.currentProfile,
    required this.onSwitch,
  });

  final List<Profile> profiles;
  final Profile? currentProfile;
  final void Function(AccountIdentity identity, String profileId,
      Completer<ProfileSwitchResult> completer) onSwitch;

  factory _ProfileSwitcherViewModel.fromStore(Store<AppState> store) {
    final profiles = store.state.teamState?.profiles ?? const <Profile>[];
    final current = store.state.authState.currentProfile;
    return _ProfileSwitcherViewModel(
      profiles: profiles,
      currentProfile: current,
      onSwitch: (identity, profileId, completer) {
        store.dispatch(SwitchProfileAction(
          identity: identity,
          profileId: profileId,
          completer: completer,
        ));
      },
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _ProfileSwitcherViewModel &&
            _listEquals(profiles, other.profiles) &&
            currentProfile == other.currentProfile;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(profiles),
        currentProfile,
      );
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

bool _listEquals(List<Profile> a, List<Profile> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
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

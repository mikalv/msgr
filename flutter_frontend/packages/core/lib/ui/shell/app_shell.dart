import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/providers/auth_state_provider.dart';
import 'package:core/providers/channel_list_provider.dart';
import 'package:core/providers/draft_provider.dart';
import 'package:core/providers/models.dart' hide ChannelKind;
import 'package:core/providers/team_list_provider.dart';
import 'package:core/providers/unread_provider.dart';

import 'channel_sidebar.dart';
import 'shell_models.dart';
import 'shell_theme.dart';
import 'team_rail.dart';

/// Main responsive app shell wrapping the chat content area.
///
/// Layout strategy:
///   - Desktop (> 1024 px): `[TeamRail | ChannelSidebar | child]`
///   - Tablet  (600-1024 px): `[ChannelSidebar | child]` with a [Drawer] for
///     the team rail.
///   - Mobile  (< 600 px): Only [child] is shown; team and channel selection
///     happens through full-screen navigation.
///
/// State is driven by Riverpod providers:
///   - [teamListProvider] / [selectedTeamProvider] for team selection
///   - [channelListProvider] / [selectedChannelProvider] for channel selection
///   - [unreadCountsProvider] for badges
///   - [channelDraftsProvider] for draft indicators
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});

  /// The chat content area that fills the remaining space.
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final teamState = ref.watch(teamListProvider);

    // Show loading while teams are being fetched
    if (teamState.isLoading && teamState.teams.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Show welcome screen when user has no teams
    if (teamState.teams.isEmpty) {
      return _WelcomeScreen(
        error: teamState.error,
        onCreateTeam: () => _showCreateTeamDialog(),
        onJoinTeam: () => _showJoinTeamDialog(),
        onRetry: () => ref.read(teamListProvider.notifier).refresh(),
      );
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 1024;
          final isTablet =
              constraints.maxWidth >= 600 && constraints.maxWidth <= 1024;

          if (isDesktop) {
            return _buildDesktop();
          } else if (isTablet) {
            return _buildTablet();
          } else {
            return _buildMobile();
          }
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers to bridge new providers into the existing shell widgets
  // ---------------------------------------------------------------------------

  List<MockTeam> get _mockTeamsFromProviders {
    final teams = ref.watch(teamsProvider);
    final unreadCounts = ref.watch(unreadCountsProvider);
    return teams.map((t) {
      // Sum unread counts for all channels in this team.
      final channels = ref.read(channelListProvider).channels;
      var teamUnread = 0;
      for (final ch in channels) {
        if (ch.teamSlug == t.slug) {
          teamUnread += unreadCounts[ch.id] ?? 0;
        }
      }
      return MockTeam(
        id: t.id,
        name: t.name,
        slug: t.slug,
        iconEmoji: t.iconEmoji ?? '\u{1F4AC}',
        unreadCount: teamUnread,
      );
    }).toList();
  }

  int get _selectedTeamIndex {
    final selectedTeam = ref.watch(selectedTeamProvider);
    final teams = ref.watch(teamsProvider);
    if (selectedTeam == null || teams.isEmpty) return 0;
    final idx = teams.indexWhere((t) => t.id == selectedTeam.id);
    return idx >= 0 ? idx : 0;
  }

  SlackTeam? get _activeTeam => ref.watch(selectedTeamProvider);

  List<MockChannel> get _mockChannelsFromProviders {
    final channelState = ref.watch(channelListProvider);
    final unreadCounts = ref.watch(unreadCountsProvider);
    final drafts = ref.watch(channelDraftsProvider);
    return channelState.publicChannels.map((c) {
      return MockChannel(
        id: c.id,
        name: c.name,
        slug: c.slug,
        iconEmoji: c.icon ?? '#',
        kind: ChannelKind.public,
        unreadCount: unreadCounts[c.id] ?? 0,
        hasDraft: drafts[c.id]?.isNotEmpty ?? false,
      );
    }).toList();
  }

  List<MockDmContact> get _mockDmsFromProviders {
    final channelState = ref.watch(channelListProvider);
    final unreadCounts = ref.watch(unreadCountsProvider);
    return channelState.dmChannels.map((c) {
      return MockDmContact(
        id: c.id,
        name: c.name,
        isOnline: false, // TODO: wire up presence
        unreadCount: unreadCounts[c.id] ?? 0,
      );
    }).toList();
  }

  String? get _selectedChannelId {
    return ref.watch(selectedChannelProvider)?.id;
  }

  // ---------------------------------------------------------------------------
  // Desktop: TeamRail + ChannelSidebar + content
  // ---------------------------------------------------------------------------
  Widget _buildDesktop() {
    return Row(
      children: [
        TeamRail(
          teams: _mockTeamsFromProviders,
          selectedIndex: _selectedTeamIndex,
          onTeamSelected: _onTeamSelected,
          onAddTeam: _showCreateTeamDialog,
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: _sidebarCollapsed ? 0 : ShellTheme.sidebarWidth,
          curve: Curves.easeInOut,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: _sidebarCollapsed
              ? const SizedBox.shrink()
              : _buildSidebar(),
        ),
        Expanded(child: widget.child),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tablet: ChannelSidebar + content, team rail in a Drawer
  // ---------------------------------------------------------------------------
  Widget _buildTablet() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: Drawer(
        width: ShellTheme.teamRailWidth + ShellTheme.sidebarWidth,
        child: Row(
          children: [
            TeamRail(
              teams: _mockTeamsFromProviders,
              selectedIndex: _selectedTeamIndex,
              onTeamSelected: (index) {
                _onTeamSelected(index);
                Navigator.of(context).pop(); // close drawer
              },
              onAddTeam: _showCreateTeamDialog,
            ),
            Expanded(child: _buildSidebar()),
          ],
        ),
      ),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile: content only (team/channel via navigation)
  // ---------------------------------------------------------------------------
  Widget _buildMobile() {
    final teamName = _activeTeam?.name ?? '';
    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Row(
          children: [
            TeamRail(
              teams: _mockTeamsFromProviders,
              selectedIndex: _selectedTeamIndex,
              onTeamSelected: (index) {
                _onTeamSelected(index);
              },
              onAddTeam: _showCreateTeamDialog,
            ),
            Expanded(child: _buildSidebar()),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text(
          teamName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: ShellTheme.sidebarBg,
        foregroundColor: ShellTheme.sidebarTextBright,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: widget.child,
    );
  }

  // ---------------------------------------------------------------------------
  // Shared sidebar builder
  // ---------------------------------------------------------------------------
  Widget _buildSidebar() {
    final teamName = _activeTeam?.name ?? '';
    return ChannelSidebar(
      teamName: teamName,
      channels: _mockChannelsFromProviders,
      dmContacts: _mockDmsFromProviders,
      selectedChannelId: _selectedChannelId,
      selectedDmId: null, // DMs share the selectedChannelProvider
      onChannelSelected: (channel) {
        _onChannelSelected(channel.id);
      },
      onDmSelected: (dm) {
        _onDmSelected(dm.id);
      },
      onCreateChannel: _showCreateChannelDialog,
      userEmail: ref.watch(simpleAuthProvider).email,
      onLogout: () => ref.read(simpleAuthProvider.notifier).logout(),
    );
  }

  // ---------------------------------------------------------------------------
  // Callbacks
  // ---------------------------------------------------------------------------
  void _onTeamSelected(int index) {
    final teams = ref.read(teamsProvider);
    if (index >= 0 && index < teams.length) {
      ref.read(selectedTeamProvider.notifier).select(teams[index]);
      // Clear channel selection when switching teams.
      ref.read(selectedChannelProvider.notifier).clear();
    }
  }

  void _onChannelSelected(String channelId) {
    final channels = ref.read(channelListProvider).channels;
    final channel = channels.where((c) => c.id == channelId).firstOrNull;
    if (channel != null) {
      ref.read(selectedChannelProvider.notifier).select(channel);
      ref.read(unreadCountsProvider.notifier).markRead(channelId);
    }
  }

  void _onDmSelected(String dmId) {
    _onChannelSelected(dmId);
  }

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------

  Future<void> _showCreateTeamDialog() async {
    final nameController = TextEditingController();
    final slugController = TextEditingController();
    bool autoSlug = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2A2A3E),
              title: const Text(
                'Opprett team',
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Teamnavn',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        hintText: 'F.eks. Min bedrift',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        if (autoSlug) {
                          slugController.text = _nameToSlug(value);
                          setDialogState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: slugController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Slug (URL-vennlig)',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        hintText: 'min-bedrift',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) {
                        autoSlug = false;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Avbryt', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF02ac88),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Opprett'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      final name = nameController.text.trim();
      final slug = slugController.text.trim();
      if (name.isNotEmpty && slug.isNotEmpty) {
        await ref.read(teamListProvider.notifier).createTeam(name, slug);
        // Auto-select the newly created team via microtask to avoid
        // _dependents.isEmpty assertion.
        Future.microtask(() {
          if (!mounted) return;
          final teams = ref.read(teamsProvider);
          if (teams.isNotEmpty) {
            final newTeam = teams.lastWhere(
              (t) => t.slug == slug,
              orElse: () => teams.last,
            );
            ref.read(selectedTeamProvider.notifier).select(newTeam);
            ref.read(selectedChannelProvider.notifier).clear();
          }
        });
      }
    }

    nameController.dispose();
    slugController.dispose();
  }

  Future<void> _showJoinTeamDialog() async {
    final slugController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A3E),
          title: const Text(
            'Bli med i team',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 360,
            child: TextField(
              controller: slugController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Team-slug',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                hintText: 'F.eks. min-bedrift',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Avbryt', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF02ac88),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Bli med'),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      final slug = slugController.text.trim();
      if (slug.isNotEmpty) {
        await ref.read(teamListProvider.notifier).joinTeam(slug);
        // Auto-select the joined team via microtask to avoid
        // _dependents.isEmpty assertion.
        Future.microtask(() {
          if (!mounted) return;
          final teams = ref.read(teamsProvider);
          if (teams.isNotEmpty) {
            final joinedTeam = teams.lastWhere(
              (t) => t.slug == slug,
              orElse: () => teams.last,
            );
            ref.read(selectedTeamProvider.notifier).select(joinedTeam);
            ref.read(selectedChannelProvider.notifier).clear();
          }
        });
      }
    }

    slugController.dispose();
  }

  Future<void> _showCreateChannelDialog() async {
    final team = ref.read(selectedTeamProvider);
    if (team == null) return;

    final nameController = TextEditingController();
    final iconController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A3E),
          title: const Text(
            'Opprett kanal',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Kanalnavn',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                    hintText: 'F.eks. general',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: iconController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Ikon (emoji, valgfritt)',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                    hintText: '#',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Avbryt', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF02ac88),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Opprett'),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      final name = nameController.text.trim();
      if (name.isNotEmpty) {
        final icon = iconController.text.trim();
        await ref.read(channelListProvider.notifier).createChannel(
              teamSlug: team.slug,
              name: name,
              icon: icon.isNotEmpty ? icon : null,
            );
        // Refresh from server to ensure sidebar is in sync (the local
        // optimistic add may lack fields like kind, which causes the
        // channel to be filtered out of publicChannels).
        await ref.read(channelListProvider.notifier).refresh();
        // Auto-select newly created channel after microtask to avoid
        // _dependents.isEmpty assertion from modifying state during build.
        Future.microtask(() {
          if (!mounted) return;
          final channels = ref.read(channelListProvider).channels;
          if (channels.isNotEmpty) {
            final newChannel = channels.last;
            ref.read(selectedChannelProvider.notifier).select(newChannel);
          }
        });
      }
    }

    nameController.dispose();
    iconController.dispose();
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  static String _nameToSlug(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}

// ---------------------------------------------------------------------------
// Welcome screen (no teams)
// ---------------------------------------------------------------------------

class _WelcomeScreen extends StatelessWidget {
  const _WelcomeScreen({
    this.error,
    required this.onCreateTeam,
    required this.onJoinTeam,
    required this.onRetry,
  });

  final Object? error;
  final VoidCallback onCreateTeam;
  final VoidCallback onJoinTeam;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: Color(0xFF02ac88),
              ),
              const SizedBox(height: 24),
              const Text(
                'Velkommen til Messngr!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Opprett et nytt team eller bli med i et eksisterende.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error.toString(),
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onCreateTeam,
                  icon: const Icon(Icons.add),
                  label: const Text('Opprett team'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF02ac88),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onJoinTeam,
                  icon: const Icon(Icons.group_add),
                  label: const Text('Bli med i team'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onRetry,
                child: const Text(
                  'Last inn paa nytt',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

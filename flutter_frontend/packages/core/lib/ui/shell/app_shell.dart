import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/providers/channel_list_provider.dart';
import 'package:core/providers/draft_provider.dart';
import 'package:core/providers/models.dart';
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
    return LayoutBuilder(
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
}
